use crate::entry::Entry;
use crate::engine::index::Index;
use crate::io::store::Store;
use std::fs;
use std::io::BufRead;

pub fn run(store: &Store, index: &mut Index, path: &str, merge: bool) -> Result<(), Box<dyn std::error::Error>> {
    let file = fs::File::open(path)
        .map_err(|e| format!("cannot open {path}: {e}"))?;
    let reader = std::io::BufReader::new(file);

    let mut new_entries: Vec<Entry> = Vec::new();
    for line in reader.lines() {
        let line = line?;
        if line.trim().is_empty() { continue; }

        // Try JSONL entry first
        if let Ok(entry) = serde_json::from_str::<Entry>(&line) {
            new_entries.push(entry);
            continue;
        }

        // Try markdown: - [ ] headline #tag
        if let Some(entry) = parse_md_line(&line) {
            new_entries.push(entry);
            continue;
        }
    }

    if merge {
        // Append new entries (skip duplicates by id)
        let existing = store.read_all()?;
        let existing_ids: std::collections::HashSet<_> = existing.iter().map(|e| e.id).collect();
        let added: Vec<_> = new_entries.into_iter().filter(|e| !existing_ids.contains(&e.id)).collect();
        let count = added.len();
        for e in &added {
            store.append(e)?;
        }
        index.rebuild_from(&store.read_all()?);
        println!("imported {count} new entries (merged, {total} total)", total = existing.len() + count);
    } else {
        // Replace all
        store.write_all(&new_entries)?;
        index.rebuild_from(&new_entries);
        println!("imported {} entries (replaced)", new_entries.len());
    }

    Ok(())
}

fn parse_md_line(line: &str) -> Option<Entry> {
    // Parse: - [ ] headline #tag1 #tag2
    let trimmed = line.trim();
    let rest = trimmed
        .strip_prefix("- [ ] ")
        .or_else(|| trimmed.strip_prefix("- [x] "))
        .or_else(|| trimmed.strip_prefix("- [X] "))
        .or_else(|| trimmed.strip_prefix("* [ ] "))
        .or_else(|| trimmed.strip_prefix("* [x] "))?;

    let done = trimmed.contains("[x]") || trimmed.contains("[X]");

    // Extract tags (words starting with #)
    let mut tags: Vec<String> = Vec::new();
    let mut headline_parts: Vec<&str> = Vec::new();
    for word in rest.split_whitespace() {
        if word.starts_with('#') {
            tags.push(word.trim_start_matches('#').to_string());
        } else {
            headline_parts.push(word);
        }
    }

    if headline_parts.is_empty() { return None; }

    if done {
        let now = chrono::Local::now().format("%Y-%m-%dT%H:%M").to_string();
        tags.push(format!("done/{now}"));
    }

    Some(Entry::new(headline_parts.join(" "), String::new(), tags))
}
