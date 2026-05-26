use crate::api::SiftCore;
use crate::entry::Entry;
use std::fs;
use std::io::BufRead;

pub fn run(core: &mut SiftCore, path: &str, merge: bool) -> Result<(), Box<dyn std::error::Error>> {
    let file = fs::File::open(path).map_err(|e| format!("cannot open {path}: {e}"))?;
    let reader = std::io::BufReader::new(file);
    let mut new_entries: Vec<Entry> = Vec::new();

    for line in reader.lines() {
        let line = line?;
        if line.trim().is_empty() { continue; }
        if let Ok(entry) = serde_json::from_str::<Entry>(&line) {
            new_entries.push(entry);
            continue;
        }
        if let Some(entry) = parse_md_line(&line) {
            new_entries.push(entry);
        }
    }

    if merge {
        let existing = core.store.read_all()?;
        let existing_ids: std::collections::HashSet<_> = existing.iter().map(|e| e.id).collect();
        let added: Vec<_> = new_entries.into_iter().filter(|e| !existing_ids.contains(&e.id)).collect();
        let count = added.len();
        core.store.append_batch(&added)?;
        core.reload()?;
        println!("imported {count} new entries (merged, {total} total)", total = existing.len() + count);
    } else {
        core.store.write_all(&new_entries)?;
        core.reload()?;
        println!("imported {} entries (replaced)", new_entries.len());
    }
    Ok(())
}

fn parse_md_line(line: &str) -> Option<Entry> {
    let trimmed = line.trim();
    let rest = trimmed
        .strip_prefix("- [ ] ")
        .or_else(|| trimmed.strip_prefix("- [x] "))
        .or_else(|| trimmed.strip_prefix("- [X] "))
        .or_else(|| trimmed.strip_prefix("* [ ] "))
        .or_else(|| trimmed.strip_prefix("* [x] "))?;

    let done = trimmed.contains("[x]") || trimmed.contains("[X]");
    let mut tags: Vec<String> = Vec::new();
    let mut parts: Vec<&str> = Vec::new();
    for word in rest.split_whitespace() {
        if word.starts_with('#') {
            tags.push(word.trim_start_matches('#').to_string());
        } else {
            parts.push(word);
        }
    }
    if parts.is_empty() { return None; }
    if done {
        let now = chrono::Local::now().format("%Y-%m-%dT%H:%M").to_string();
        tags.push(format!("done/{now}"));
    }
    Some(Entry::new(parts.join(" "), String::new(), tags))
}
