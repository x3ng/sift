use crate::entry::Entry;
use std::fs;
use std::io::{BufRead, BufReader, Write};
use std::path::{Path, PathBuf};

pub struct Store {
    path: PathBuf,
    #[allow(dead_code)]
    backup_dir: PathBuf,
}

impl Store {
    pub fn new(path: PathBuf, backup_dir: PathBuf) -> Self {
        Self { path, backup_dir }
    }

    /// Append a single entry to the JSONL file
    pub fn append(&self, entry: &Entry) -> Result<(), Box<dyn std::error::Error>> {
        ensure_parent(&self.path)?;
        let line = serde_json::to_string(entry)?;
        let mut file = fs::OpenOptions::new()
            .create(true)
            .append(true)
            .open(&self.path)?;
        writeln!(file, "{line}")?;
        Ok(())
    }

    /// Read all entries from JSONL file
    pub fn read_all(&self) -> Result<Vec<Entry>, Box<dyn std::error::Error>> {
        if !self.path.exists() {
            return Ok(vec![]);
        }
        let file = fs::File::open(&self.path)?;
        let reader = BufReader::new(file);
        let mut entries = Vec::new();
        for (i, line) in reader.lines().enumerate() {
            let line = line?;
            if line.trim().is_empty() {
                continue;
            }
            match serde_json::from_str::<Entry>(&line) {
                Ok(e) => entries.push(e),
                Err(err) => eprintln!("warning: skipping malformed line {}: {err}", i + 1),
            }
        }
        Ok(entries)
    }

    /// Write all entries atomically (for edits/deletes)
    pub fn write_all(&self, entries: &[Entry]) -> Result<(), Box<dyn std::error::Error>> {
        ensure_parent(&self.path)?;
        let mut tmp_path = self.path.clone();
        tmp_path.set_extension("jsonl.tmp");

        let mut file = fs::File::create(&tmp_path)?;
        for entry in entries {
            let line = serde_json::to_string(entry)?;
            writeln!(file, "{line}")?;
        }
        file.flush()?;

        // Atomic rename
        fs::rename(&tmp_path, &self.path)?;
        Ok(())
    }

    /// Append multiple entries to the JSONL file efficiently.
    pub fn append_batch(&self, entries: &[Entry]) -> Result<(), Box<dyn std::error::Error>> {
        ensure_parent(&self.path)?;
        let mut file = fs::OpenOptions::new()
            .create(true)
            .append(true)
            .open(&self.path)?;
        for entry in entries {
            let line = serde_json::to_string(entry)?;
            writeln!(file, "{line}")?;
        }
        Ok(())
    }

    /// Replace a single entry by id. Returns true if found and replaced.
    pub fn update(
        &self,
        id: &uuid::Uuid,
        f: impl FnOnce(&mut Entry),
    ) -> Result<bool, Box<dyn std::error::Error>> {
        let mut entries = self.read_all()?;
        if let Some(entry) = entries.iter_mut().find(|e| e.id == *id) {
            f(entry);
            self.write_all(&entries)?;
            Ok(true)
        } else {
            Ok(false)
        }
    }
}

fn ensure_parent(path: &Path) -> Result<(), Box<dyn std::error::Error>> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::entry::Entry;
    use tempfile::TempDir;

    fn test_store() -> (Store, TempDir) {
        let dir = TempDir::new().unwrap();
        let path = dir.path().join("entries.jsonl");
        let backup = dir.path().join(".backup");
        (Store::new(path, backup), dir)
    }

    #[test]
    fn test_append_and_read() {
        let (store, _dir) = test_store();
        let e1 = Entry::new("one".into(), "".into(), vec!["test".into()]);
        let e2 = Entry::new("two".into(), "".into(), vec!["test".into()]);

        store.append(&e1).unwrap();
        store.append(&e2).unwrap();

        let entries = store.read_all().unwrap();
        assert_eq!(entries.len(), 2);
        assert_eq!(entries[0].headline, "one");
    }

    #[test]
    fn test_update_entry() {
        let (store, _dir) = test_store();
        let e = Entry::new("old".into(), "".into(), vec![]);
        let id = e.id;
        store.append(&e).unwrap();

        store
            .update(&id, |entry| entry.headline = "new".into())
            .unwrap();

        let entries = store.read_all().unwrap();
        assert_eq!(entries[0].headline, "new");
    }
}
