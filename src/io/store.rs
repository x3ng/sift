use crate::entry::Entry;
#[cfg(test)]
use crate::entry::Body;
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

    /// Directory for managed files (relative paths in Body::File point here).
    pub fn files_dir(&self) -> PathBuf {
        self.path.parent().unwrap_or(Path::new(".")).join("files")
    }

    /// Copy an external file into sift's managed files directory.
    /// Returns the relative path to store in Body::File.
    pub fn import_file(&self, source: &Path) -> Result<String, Box<dyn std::error::Error>> {
        let ext = source.extension().and_then(|e| e.to_str()).unwrap_or("");
        let dest_name = if ext.is_empty() {
            uuid::Uuid::new_v4().to_string()
        } else {
            format!("{}.{}", uuid::Uuid::new_v4(), ext)
        };
        let dest = self.files_dir().join(&dest_name);
        fs::create_dir_all(self.files_dir())?;
        fs::copy(source, &dest)?;
        Ok(format!("files/{}", dest_name))
    }

    /// Delete a managed file (given the relative path stored in Body::File).
    pub fn delete_file(&self, relative_path: &str) -> Result<(), Box<dyn std::error::Error>> {
        let abs = self.path.parent().unwrap_or(Path::new(".")).join(relative_path);
        if abs.exists() {
            fs::remove_file(abs)?;
        }
        Ok(())
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
        let e1 = Entry::new("one".into(), Body::Empty, vec!["test".into()]);
        let e2 = Entry::new("two".into(), Body::Empty, vec!["test".into()]);

        store.append(&e1).unwrap();
        store.append(&e2).unwrap();

        let entries = store.read_all().unwrap();
        assert_eq!(entries.len(), 2);
        assert_eq!(entries[0].name, "one");
    }

    #[test]
    fn test_update_entry() {
        let (store, _dir) = test_store();
        let e = Entry::new("old".into(), Body::Empty, vec![]);
        let id = e.id;
        store.append(&e).unwrap();

        store
            .update(&id, |entry| entry.name = "new".into())
            .unwrap();

        let entries = store.read_all().unwrap();
        assert_eq!(entries[0].name, "new");
    }
}
