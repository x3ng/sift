use crate::entry::Entry;
use chrono::NaiveDateTime;
use std::collections::{HashMap, HashSet};
use uuid::Uuid;

pub struct Index {
    /// tag -> set of entry ids
    pub tag_index: HashMap<String, HashSet<Uuid>>,
    /// id -> created datetime (from created/* tag)
    pub created_times: HashMap<Uuid, NaiveDateTime>,
    /// id -> due datetime (from first matching date-prefix tag, excluding created/done)
    pub due_times: HashMap<Uuid, NaiveDateTime>,
    /// id -> done datetime (from done/* tag)
    pub done_times: HashMap<Uuid, NaiveDateTime>,
    /// All known tags and their counts
    pub tag_counts: HashMap<String, usize>,
    /// All entries (id -> entry)
    pub entries: HashMap<Uuid, Entry>,
}

impl Default for Index {
    fn default() -> Self {
        Self::new()
    }
}

impl Index {
    pub fn new() -> Self {
        Self {
            tag_index: HashMap::new(),
            created_times: HashMap::new(),
            due_times: HashMap::new(),
            done_times: HashMap::new(),
            tag_counts: HashMap::new(),
            entries: HashMap::new(),
        }
    }

    pub fn rebuild_from(&mut self, entries: &[Entry]) {
        self.tag_index.clear();
        self.created_times.clear();
        self.due_times.clear();
        self.done_times.clear();
        self.tag_counts.clear();
        self.entries.clear();

        for entry in entries {
            self.entries.insert(entry.id, entry.clone());
            for tag in &entry.tags {
                self.tag_index
                    .entry(tag.clone())
                    .or_default()
                    .insert(entry.id);
                *self.tag_counts.entry(tag.clone()).or_default() += 1;

                if let Some(ts) = parse_tag_timestamp(tag, "created/") {
                    self.created_times.insert(entry.id, ts);
                }
                if let Some(ts) = parse_tag_timestamp(tag, "done/") {
                    self.done_times.insert(entry.id, ts);
                }
                if let Some(ts) = parse_tag_timestamp(tag, "due/") {
                    self.due_times.entry(entry.id).or_insert(ts);
                }
            }
        }
    }

    pub fn add_entry(&mut self, entry: Entry) {
        for tag in &entry.tags {
            self.tag_index
                .entry(tag.clone())
                .or_default()
                .insert(entry.id);
            *self.tag_counts.entry(tag.clone()).or_default() += 1;

            if let Some(ts) = parse_tag_timestamp(tag, "created/") {
                self.created_times.insert(entry.id, ts);
            }
            if let Some(ts) = parse_tag_timestamp(tag, "due/") {
                self.due_times.entry(entry.id).or_insert(ts);
            }
        }
        self.entries.insert(entry.id, entry);
    }

    pub fn remove_entry(&mut self, id: &Uuid) {
        if let Some(entry) = self.entries.remove(id) {
            for tag in &entry.tags {
                if let Some(set) = self.tag_index.get_mut(tag) {
                    set.remove(id);
                }
                if let Some(count) = self.tag_counts.get_mut(tag) {
                    *count = count.saturating_sub(1);
                }
            }
            self.created_times.remove(id);
            self.due_times.remove(id);
            self.done_times.remove(id);
        }
    }

    pub fn update_entry(&mut self, entry: Entry) {
        self.remove_entry(&entry.id);
        self.add_entry(entry);
    }

    pub fn all_tags(&self) -> Vec<(String, usize)> {
        let mut tags: Vec<_> = self
            .tag_counts
            .iter()
            .map(|(k, v)| (k.clone(), *v))
            .collect();
        tags.sort_by(|a, b| b.1.cmp(&a.1));
        tags
    }
}

fn parse_tag_timestamp(tag: &str, prefix: &str) -> Option<NaiveDateTime> {
    if let Some(suffix) = tag.strip_prefix(prefix) {
        let fmts = ["%Y-%m-%dT%H:%M", "%Y-%m-%dT%H:%M:%S", "%Y-%m-%d"];
        for fmt in &fmts {
            if let Ok(dt) = NaiveDateTime::parse_from_str(suffix, fmt) {
                return Some(dt);
            }
        }
        if let Ok(d) = chrono::NaiveDate::parse_from_str(suffix, "%Y-%m-%d") {
            return d.and_hms_opt(0, 0, 0);
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::entry::Entry;

    #[test]
    fn test_index_rebuild() {
        let entries = vec![
            Entry::new(
                "one".into(),
                "".into(),
                vec!["work".into(), "created/2026-05-20T10:00".into()],
            ),
            Entry::new(
                "two".into(),
                "".into(),
                vec!["life".into(), "created/2026-05-21T10:00".into()],
            ),
        ];
        let mut idx = Index::new();
        idx.rebuild_from(&entries);

        assert_eq!(idx.entries.len(), 2);
        assert_eq!(idx.tag_counts.get("work").copied(), Some(1));
        assert_eq!(idx.tag_counts.get("life").copied(), Some(1));
        assert_eq!(idx.created_times.len(), 2);
    }

    #[test]
    fn test_tag_counts_sorted() {
        let entries = vec![
            Entry::new("a".into(), "".into(), vec!["common".into(), "rare".into()]),
            Entry::new("b".into(), "".into(), vec!["common".into()]),
            Entry::new("c".into(), "".into(), vec!["common".into()]),
        ];
        let mut idx = Index::new();
        idx.rebuild_from(&entries);

        let tags = idx.all_tags();
        assert_eq!(tags[0].0, "common");
        assert_eq!(tags[0].1, 3);
    }
}
