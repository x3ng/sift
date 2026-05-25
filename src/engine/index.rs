use crate::entry::Entry;
use crate::engine::types::parse_tag_date;
use chrono::NaiveDateTime;
use std::collections::{HashMap, HashSet};
use uuid::Uuid;

pub struct Index {
    pub tag_index: HashMap<String, HashSet<Uuid>>,
    /// id → first created datetime (from any prefix ending with /)
    pub created_times: HashMap<Uuid, NaiveDateTime>,
    /// id → first "due" datetime
    pub due_times: HashMap<Uuid, NaiveDateTime>,
    pub tag_counts: HashMap<String, usize>,
    pub entries: HashMap<Uuid, Entry>,
}

impl Default for Index {
    fn default() -> Self { Self::new() }
}

impl Index {
    pub fn new() -> Self {
        Self {
            tag_index: HashMap::new(),
            created_times: HashMap::new(),
            due_times: HashMap::new(),
            tag_counts: HashMap::new(),
            entries: HashMap::new(),
        }
    }

    /// Rebuild the index from entries, using config-provided date prefixes.
    /// `date_prefixes`: map of prefix → format string (e.g. "created/" → "%Y-%m-%dT%H:%M").
    pub fn rebuild_from(&mut self, entries: &[Entry], date_prefixes: &HashMap<String, String>) {
        self.clear();
        for entry in entries {
            self.entries.insert(entry.id, entry.clone());
            for tag in &entry.tags {
                self.tag_index.entry(tag.clone()).or_default().insert(entry.id);
                *self.tag_counts.entry(tag.clone()).or_default() += 1;
                self.index_date_tag(entry.id, tag, date_prefixes);
            }
        }
    }

    pub fn add_entry(&mut self, entry: Entry, date_prefixes: &HashMap<String, String>) {
        for tag in &entry.tags {
            self.tag_index.entry(tag.clone()).or_default().insert(entry.id);
            *self.tag_counts.entry(tag.clone()).or_default() += 1;
            self.index_date_tag(entry.id, tag, date_prefixes);
        }
        self.entries.insert(entry.id, entry);
    }

    fn index_date_tag(&mut self, id: Uuid, tag: &str, date_prefixes: &HashMap<String, String>) {
        for prefix in date_prefixes.keys() {
            if let Some(ts) = parse_tag_timestamp(tag, prefix) {
                match prefix.as_str() {
                    "due/" => { self.due_times.entry(id).or_insert(ts); }
                    _ => { self.created_times.entry(id).or_insert(ts); }
                }
            }
        }
    }

    pub fn remove_entry(&mut self, id: &Uuid) {
        if let Some(entry) = self.entries.remove(id) {
            for tag in &entry.tags {
                if let Some(set) = self.tag_index.get_mut(tag) { set.remove(id); }
                if let Some(count) = self.tag_counts.get_mut(tag) { *count = count.saturating_sub(1); }
            }
            self.created_times.remove(id);
            self.due_times.remove(id);
        }
    }

    pub fn update_entry(&mut self, entry: Entry, date_prefixes: &HashMap<String, String>) {
        self.remove_entry(&entry.id);
        self.add_entry(entry, date_prefixes);
    }

    pub fn all_tags(&self) -> Vec<(String, usize)> {
        let mut tags: Vec<_> = self.tag_counts.iter().map(|(k, v)| (k.clone(), *v)).collect();
        tags.sort_by(|a, b| b.1.cmp(&a.1));
        tags
    }

    fn clear(&mut self) {
        self.tag_index.clear();
        self.created_times.clear();
        self.due_times.clear();
        self.tag_counts.clear();
        self.entries.clear();
    }
}

fn parse_tag_timestamp(tag: &str, prefix: &str) -> Option<NaiveDateTime> {
    parse_tag_date(tag, prefix)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::entry::{Body, Entry};
    use std::collections::HashMap;

    fn test_prefixes() -> HashMap<String, String> {
        let mut m = HashMap::new();
        m.insert("created/".into(), "%Y-%m-%dT%H:%M".into());
        m.insert("done/".into(), "%Y-%m-%dT%H:%M".into());
        m.insert("due/".into(), "%Y-%m-%d".into());
        m
    }

    #[test]
    fn test_index_rebuild() {
        let entries = vec![
            Entry::new("one".into(), Body::Empty, vec!["work".into(), "created/2026-05-20T10:00".into()]),
            Entry::new("two".into(), Body::Empty, vec!["life".into(), "created/2026-05-21T10:00".into()]),
        ];
        let mut idx = Index::new();
        idx.rebuild_from(&entries, &test_prefixes());
        assert_eq!(idx.entries.len(), 2);
        assert_eq!(idx.tag_counts.get("work").copied(), Some(1));
        assert_eq!(idx.created_times.len(), 2);
    }

    #[test]
    fn test_tag_counts_sorted() {
        let entries = vec![
            Entry::new("a".into(), Body::Empty, vec!["common".into(), "rare".into()]),
            Entry::new("b".into(), Body::Empty, vec!["common".into()]),
            Entry::new("c".into(), Body::Empty, vec!["common".into()]),
        ];
        let mut idx = Index::new();
        idx.rebuild_from(&entries, &test_prefixes());
        let tags = idx.all_tags();
        assert_eq!(tags[0].0, "common");
        assert_eq!(tags[0].1, 3);
    }

    #[test]
    fn test_index_uses_config_prefixes() {
        let entries = vec![
            Entry::new("x".into(), Body::Empty, vec!["meeting/2026-06-01T09:00".into()]),
        ];
        let mut prefixes = test_prefixes();
        prefixes.insert("meeting/".into(), "%Y-%m-%dT%H:%M".into());

        let mut idx = Index::new();
        idx.rebuild_from(&entries, &prefixes);
        assert_eq!(idx.created_times.len(), 1); // meeting/ goes to created_times
    }
}
