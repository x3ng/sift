use crate::config::Config;
use crate::engine::combinator::{self, parse_query, ParsedQuery};
use crate::engine::filter::{DateFilter, DateOp as FilterDateOp, FilterOptions, SortMode};
use crate::engine::index::Index;
use crate::entry::{Body, Entry};
use crate::io::store::Store;
use std::path::PathBuf;

pub struct SiftCore {
    pub store: Store,
    pub index: Index,
    pub cfg: Config,
}

impl SiftCore {
    pub fn new(data_dir: Option<String>) -> Result<Self, String> {
        let mut cfg = Config::load().map_err(|e| e.to_string())?;
        if let Some(dir) = data_dir {
            cfg.data_dir = PathBuf::from(dir);
            cfg.save().ok();
        }
        let store = Store::new(cfg.entries_path(), cfg.backup_dir());
        let entries = store.read_all().map_err(|e| e.to_string())?;
        let mut index = Index::new();
        index.rebuild_from(&entries, &cfg.tags.date_prefixes);
        Ok(Self { store, index, cfg })
    }

    pub fn reload(&mut self) -> Result<(), String> {
        let entries = self.store.read_all().map_err(|e| e.to_string())?;
        self.index.rebuild_from(&entries, &self.cfg.tags.date_prefixes);
        Ok(())
    }

    pub fn add(&mut self, name: String, body: Body, tags: Vec<String>) -> Result<Entry, String> {
        let entry = Entry::new(name, body, tags);
        self.store.append(&entry).map_err(|e| e.to_string())?;
        self.index.add_entry(entry.clone(), &self.cfg.tags.date_prefixes);
        Ok(entry)
    }

    pub fn list(&self, tags_and: Vec<String>, tags_or: Vec<String>, tags_not: Vec<String>,
                due: Option<String>, show_done: bool, sort: String) -> Result<Vec<Entry>, String> {
        let date_filters = match due.as_deref() {
            Some("today") => vec![DateFilter { prefix: "due".into(), op: FilterDateOp::Today }],
            Some("tomorrow") => vec![DateFilter { prefix: "due".into(), op: FilterDateOp::Tomorrow }],
            Some("this-week") => vec![DateFilter { prefix: "due".into(), op: FilterDateOp::ThisWeek }],
            Some("overdue") => vec![DateFilter { prefix: "due".into(), op: FilterDateOp::Overdue }],
            Some(_) => return Err("specific dates not supported via --due; use a period name".into()),
            None => vec![],
        };
        let sort_mode = match sort.as_str() {
            "created" => SortMode::Created,
            "due" => SortMode::Due,
            _ => SortMode::Default,
        };
        let opts = FilterOptions {
            tags_and, tags_or, tags_not, date_filters,
            show_done, only_done: false,
            sort_by: sort_mode,
        };
        let mut ids = opts.apply(&self.index);
        crate::engine::filter::sort_ids(&mut ids, &self.index, &opts.sort_by, &self.cfg.tags.priority_order);
        Ok(ids.iter().filter_map(|id| self.index.entries.get(id).cloned()).collect())
    }

    /// Parse a combinator query string and list matching entries.
    /// Supports the full combinator syntax: #tag, -#tag, prefix:period, @view, "fulltext".
    pub fn list_parsed(&self, query: &str, show_done: bool) -> Result<Vec<Entry>, String> {
        let mut pq = parse_query(query);
        self.resolve_views(&mut pq)?;
        self.apply_parsed(&pq, show_done)
    }

    fn resolve_views(&self, pq: &mut ParsedQuery) -> Result<(), String> {
        self.resolve_views_inner(pq)?;
        for alt in &mut pq.alternatives {
            self.resolve_views_inner(alt)?;
        }
        Ok(())
    }

    fn resolve_views_inner(&self, pq: &mut ParsedQuery) -> Result<(), String> {
        if pq.views.is_empty() {
            return Ok(());
        }
        for view_name in std::mem::take(&mut pq.views) {
            let view_entry = self.index.entries.values().find(|e| {
                e.has_tag("$view") && e.name.to_lowercase() == view_name.to_lowercase()
            });
            let Some(view) = view_entry else {
                return Err(format!("view not found: @{view_name}"));
            };
            let expr = view.body.text().unwrap_or("").to_string();
            if expr.is_empty() {
                return Err(format!("view @{view_name} has no body expression"));
            }
            let view_pq = parse_query(&expr);
            pq.tags_and.extend(view_pq.tags_and);
            pq.tags_or.extend(view_pq.tags_or);
            pq.tags_not.extend(view_pq.tags_not);
            pq.dates.extend(view_pq.dates);
            if let Some(ft) = view_pq.fulltext {
                pq.fulltext = Some(match pq.fulltext.take() {
                    Some(existing) => format!("{existing} {ft}"),
                    None => ft,
                });
            }
            if pq.sort_by.is_none() {
                pq.sort_by = view_pq.sort_by;
            }
            pq.alternatives.extend(view_pq.alternatives);
        }
        Ok(())
    }

    /// Apply an already-parsed (and view-resolved) query to the index.
    fn apply_parsed(&self, pq: &ParsedQuery, show_done: bool) -> Result<Vec<Entry>, String> {
        // Determine sort mode: query directive > default
        let sort_mode = match pq.sort_by {
            Some(combinator::SortDirective::Due) => SortMode::Due,
            Some(combinator::SortDirective::Created) => SortMode::Created,
            None => SortMode::Default,
        };

        let mut all_entries = self.apply_one(pq, show_done, &sort_mode)?;

        // Union with | alternatives
        for alt in &pq.alternatives {
            let alt_entries = self.apply_one(alt, show_done, &sort_mode)?;
            let existing_ids: std::collections::HashSet<_> = all_entries.iter().map(|e| e.id).collect();
            for e in alt_entries {
                if !existing_ids.contains(&e.id) {
                    all_entries.push(e);
                }
            }
        }

        Ok(all_entries)
    }

    fn apply_one(&self, pq: &ParsedQuery, show_done: bool, sort_mode: &SortMode) -> Result<Vec<Entry>, String> {
        let date_filters: Vec<DateFilter> = pq.dates.iter().map(|dc| {
            let op = match dc.op {
                combinator::DateOp::Today => FilterDateOp::Today,
                combinator::DateOp::Yesterday => FilterDateOp::Yesterday,
                combinator::DateOp::Tomorrow => FilterDateOp::Tomorrow,
                combinator::DateOp::ThisWeek => FilterDateOp::ThisWeek,
                combinator::DateOp::LastWeek => FilterDateOp::LastWeek,
                combinator::DateOp::NextWeek => FilterDateOp::NextWeek,
                combinator::DateOp::ThisMonth => FilterDateOp::ThisMonth,
                combinator::DateOp::LastMonth => FilterDateOp::LastMonth,
                combinator::DateOp::Overdue => FilterDateOp::Overdue,
            };
            DateFilter { prefix: dc.prefix.clone(), op }
        }).collect();

        let opts = FilterOptions {
            tags_and: pq.tags_and.clone(),
            tags_or: pq.tags_or.clone(),
            tags_not: pq.tags_not.clone(),
            date_filters,
            show_done,
            only_done: false,
            sort_by: *sort_mode,  // Copy now available
        };
        let mut ids = opts.apply(&self.index);
        crate::engine::filter::sort_ids(
            &mut ids,
            &self.index,
            &opts.sort_by,
            &self.cfg.tags.priority_order,
        );
        let mut entries: Vec<Entry> = ids
            .iter()
            .filter_map(|id| self.index.entries.get(id).cloned())
            .collect();
        if let Some(ref ft) = pq.fulltext {
            let q = ft.to_lowercase();
            entries.retain(|e| {
                e.name.to_lowercase().contains(&q)
                    || e.body.searchable_text().to_lowercase().contains(&q)
                    || e.tags.iter().any(|t| t.to_lowercase().contains(&q))
            });
        }
        Ok(entries)
    }

    pub fn edit(&mut self, id: String, name: Option<String>, body: Option<Body>) -> Result<bool, String> {
        let uid = resolve_uuid(&self.index, &id)?;
        self.store.update(&uid, |entry| {
            if let Some(n) = name { entry.name = n; }
            if let Some(b) = body { entry.body = b; }
        }).map_err(|e| e.to_string())?;
        self.reload()?;
        Ok(true)
    }

    pub fn delete(&mut self, id: String) -> Result<bool, String> {
        let uid = resolve_uuid(&self.index, &id)?;
        // Clean up managed file if body is a file reference
        if let Some(entry) = self.index.entries.get(&uid) {
            if let Some(path) = entry.body.file_path() {
                self.store.delete_file(path).ok();
            }
        }
        let mut entries = self.store.read_all().map_err(|e| e.to_string())?;
        entries.retain(|e| e.id != uid);
        self.store.write_all(&entries).map_err(|e| e.to_string())?;
        self.reload()?;
        Ok(true)
    }

    pub fn tag(&mut self, id: String, add_tags: Vec<String>, rm_tags: Vec<String>) -> Result<bool, String> {
        let uid = resolve_uuid(&self.index, &id)?;
        self.store.update(&uid, |entry| {
            for tag in &add_tags {
                let clean = tag.trim().trim_start_matches('#');
                if !entry.tags.iter().any(|t| t == clean) {
                    entry.tags.push(clean.to_string());
                }
            }
            for pattern in &rm_tags {
                if pattern.ends_with('*') {
                    let prefix = pattern.trim_end_matches('*');
                    entry.tags.retain(|t| !t.starts_with(prefix));
                } else {
                    let clean = pattern.trim().trim_start_matches('#');
                    entry.tags.retain(|t| t != clean);
                }
            }
            entry.tags.sort();
            entry.tags.dedup();
        }).map_err(|e| e.to_string())?;
        self.reload()?;
        Ok(true)
    }

    /// Rename a tag globally across all entries. Returns count modified.
    pub fn rename_tag(&mut self, old: &str, new: &str) -> Result<usize, String> {
        let mut entries = self.store.read_all().map_err(|e| e.to_string())?;
        let mut modified = 0;
        for entry in &mut entries {
            if entry.tags.contains(&old.to_string()) {
                entry.tags.retain(|t| t != old);
                if !entry.tags.contains(&new.to_string()) {
                    entry.tags.push(new.to_string());
                }
                entry.tags.sort();
                entry.tags.dedup();
                modified += 1;
            }
        }
        if modified > 0 {
            self.store.write_all(&entries).map_err(|e| e.to_string())?;
            self.reload()?;
        }
        Ok(modified)
    }

    /// Get a single entry by id prefix. Returns None if not found or ambiguous.
    pub fn get_entry(&self, id_prefix: &str) -> Option<Entry> {
        let matches: Vec<&Entry> = self.index.entries.values()
            .filter(|e| e.id.to_string().starts_with(id_prefix))
            .collect();
        if matches.len() == 1 { Some(matches[0].clone()) } else { None }
    }

    /// Delete multiple entries by id prefix. Returns count deleted.
    pub fn batch_delete(&mut self, id_prefixes: Vec<String>) -> Result<usize, String> {
        let mut entries = self.store.read_all().map_err(|e| e.to_string())?;
        let before = entries.len();
        entries.retain(|e| !id_prefixes.iter().any(|p| e.id.to_string().starts_with(p)));
        let deleted = before - entries.len();
        if deleted > 0 {
            self.store.write_all(&entries).map_err(|e| e.to_string())?;
            self.reload()?;
        }
        Ok(deleted)
    }

    /// Add/remove tags on multiple entries by id prefix. Returns count modified.
    pub fn batch_tag(&mut self, id_prefixes: Vec<String>, add_tags: Vec<String>, rm_tags: Vec<String>) -> Result<usize, String> {
        let mut entries = self.store.read_all().map_err(|e| e.to_string())?;
        let mut modified = 0;
        for entry in &mut entries {
            if !id_prefixes.iter().any(|p| entry.id.to_string().starts_with(p)) {
                continue;
            }
            let mut changed = false;
            for tag in &add_tags {
                let clean = tag.trim().trim_start_matches('#');
                if !entry.tags.iter().any(|t| t == clean) {
                    entry.tags.push(clean.to_string());
                    changed = true;
                }
            }
            for pattern in &rm_tags {
                if pattern.ends_with('*') {
                    let prefix = pattern.trim_end_matches('*');
                    let before = entry.tags.len();
                    entry.tags.retain(|t| !t.starts_with(prefix));
                    if entry.tags.len() < before { changed = true; }
                } else {
                    let clean = pattern.trim().trim_start_matches('#');
                    if entry.tags.iter().any(|t| t == clean) {
                        entry.tags.retain(|t| t != clean);
                        changed = true;
                    }
                }
            }
            if changed {
                entry.tags.sort();
                entry.tags.dedup();
                modified += 1;
            }
        }
        if modified > 0 {
            self.store.write_all(&entries).map_err(|e| e.to_string())?;
            self.reload()?;
        }
        Ok(modified)
    }

    /// Export all entries to a JSONL file.
    pub fn export_to(&self, path: String) -> Result<(), String> {
        let entries = self.store.read_all().map_err(|e| e.to_string())?;
        let mut content = String::new();
        for entry in &entries {
            let line = serde_json::to_string(entry).map_err(|e| e.to_string())?;
            content.push_str(&line);
            content.push('\n');
        }
        std::fs::create_dir_all(
            std::path::Path::new(&path).parent().unwrap_or(std::path::Path::new(".")),
        ).map_err(|e| e.to_string())?;
        std::fs::write(&path, &content).map_err(|e| e.to_string())?;
        Ok(())
    }

    /// Import entries from a JSONL file (merge: skip duplicates by id).
    pub fn import_from(&mut self, path: String) -> Result<usize, String> {
        let content = std::fs::read_to_string(&path).map_err(|e| e.to_string())?;
        let existing_ids: std::collections::HashSet<uuid::Uuid> =
            self.index.entries.keys().copied().collect();
        let mut new_entries = Vec::new();
        for line in content.lines() {
            let trimmed = line.trim();
            if trimmed.is_empty() { continue; }
            if let Ok(entry) = serde_json::from_str::<Entry>(trimmed) {
                if !existing_ids.contains(&entry.id) {
                    new_entries.push(entry);
                }
            }
        }
        let added = new_entries.len();
        if added > 0 {
            self.store.append_batch(&new_entries).map_err(|e| e.to_string())?;
            self.reload()?;
        }
        Ok(added)
    }

    pub fn all_tags(&self) -> Vec<(String, usize)> {
        self.index.all_tags()
    }

    pub fn search(&self, query: String) -> Vec<Entry> {
        let q = query.to_lowercase();
        self.index.entries.values()
            .filter(|e| e.name.to_lowercase().contains(&q)
                     || e.body.searchable_text().to_lowercase().contains(&q)
                     || e.tags.iter().any(|t| t.to_lowercase().contains(&q)))
            .cloned()
            .collect()
    }

    pub fn stats(&self) -> StatsData {
        let total = self.index.entries.len();
        let active = self.index.entries.values().filter(|e| !e.is_done()).count();
        let done = total - active;
        let unique_tags = self.index.tag_counts.len();
        StatsData { total, active, done, unique_tags }
    }
}

pub struct StatsData {
    pub total: usize,
    pub active: usize,
    pub done: usize,
    pub unique_tags: usize,
}

fn resolve_uuid(index: &Index, prefix: &str) -> Result<uuid::Uuid, String> {
    let matches: Vec<uuid::Uuid> = index.entries.keys()
        .filter(|id| id.to_string().starts_with(prefix))
        .copied()
        .collect();
    match matches.len() {
        0 => Err(format!("no entry matching '{prefix}'")),
        1 => Ok(matches[0]),
        n => Err(format!("{n} entries match '{prefix}', be more specific")),
    }
}
