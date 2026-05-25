use crate::engine::index::Index;
use chrono::{Datelike, Local, NaiveDate, NaiveDateTime};
use std::collections::HashSet;
use uuid::Uuid;

pub struct FilterOptions {
    pub tags_and: Vec<String>,
    pub tags_or: Vec<String>,
    pub tags_not: Vec<String>,
    pub due_period: Option<DuePeriod>,
    pub show_done: bool,
    pub only_done: bool,
    pub sort_by: SortMode,
}

pub enum DuePeriod {
    Today,
    Tomorrow,
    ThisWeek,
    Overdue,
    Before(NaiveDate),
}

pub enum SortMode {
    Default,
    Created,
    Due,
    Modified,
}

impl FilterOptions {
    pub fn apply(&self, index: &Index) -> Vec<Uuid> {
        let mut ids: HashSet<Uuid> = index.entries.keys().copied().collect();

        // Done filter
        if self.only_done {
            ids.retain(|id| index.entries.get(id).is_some_and(|e| e.is_done()));
        } else if !self.show_done {
            ids.retain(|id| index.entries.get(id).is_none_or(|e| !e.is_done()));
        }

        // Tag intersection (--tag)
        for pattern in &self.tags_and {
            let matching = resolve_tag_pattern(pattern, index);
            ids.retain(|id| {
                matching
                    .iter()
                    .any(|tag| index.tag_index.get(tag).is_some_and(|s| s.contains(id)))
            });
        }

        // Tag union (--any)
        if !self.tags_or.is_empty() {
            let mut union_ids: HashSet<Uuid> = HashSet::new();
            for pattern in &self.tags_or {
                let matching = resolve_tag_pattern(pattern, index);
                for tag in &matching {
                    if let Some(set) = index.tag_index.get(tag) {
                        union_ids.extend(set);
                    }
                }
            }
            ids.retain(|id| union_ids.contains(id));
        }

        // Tag exclusion (--exclude)
        for pattern in &self.tags_not {
            let matching = resolve_tag_pattern(pattern, index);
            ids.retain(|id| {
                !matching
                    .iter()
                    .any(|tag| index.tag_index.get(tag).is_some_and(|s| s.contains(id)))
            });
        }

        // Due period filter
        if let Some(period) = &self.due_period {
            let today = Local::now().date_naive();
            ids.retain(|id| {
                let due = index.due_times.get(id).map(|dt| dt.date());
                match period {
                    DuePeriod::Today => due == Some(today),
                    DuePeriod::Tomorrow => due == Some(today + chrono::Duration::days(1)),
                    DuePeriod::ThisWeek => {
                        if let Some(d) = due {
                            let days_to_end = 7 - today.weekday().num_days_from_monday() as i64;
                            let week_end = today + chrono::Duration::days(days_to_end);
                            d >= today && d <= week_end
                        } else {
                            false
                        }
                    }
                    DuePeriod::Overdue => due.is_some_and(|d| d < today),
                    DuePeriod::Before(date) => due.is_some_and(|d| d <= *date),
                }
            });
        }

        ids.into_iter().collect()
    }
}

fn resolve_tag_pattern(pattern: &str, index: &Index) -> Vec<String> {
    if pattern.ends_with('*') {
        let prefix = pattern.trim_end_matches('*');
        index
            .tag_counts
            .keys()
            .filter(|t| t.starts_with(prefix))
            .cloned()
            .collect()
    } else {
        vec![pattern.to_string()]
    }
}

/// Sort entry IDs according to sort mode and priority config
pub fn sort_ids(ids: &mut [Uuid], index: &Index, mode: &SortMode, priority_order: &[String]) {
    match mode {
        SortMode::Created => {
            ids.sort_by_key(|id| index.created_times.get(id).copied());
        }
        SortMode::Due => {
            ids.sort_by_key(|id| index.due_times.get(id).copied());
        }
        SortMode::Modified => {
            ids.sort_by_key(|id| {
                index.entries.get(id).and_then(|e| {
                    e.tags.iter().find_map(|t| {
                        t.strip_prefix("modified/")
                            .and_then(|s| NaiveDateTime::parse_from_str(s, "%Y-%m-%dT%H:%M").ok())
                    })
                })
            });
        }
        SortMode::Default => {
            ids.sort_by(|a, b| {
                let prio_a = priority_score(a, index, priority_order);
                let prio_b = priority_score(b, index, priority_order);
                prio_b
                    .cmp(&prio_a)
                    .then_with(|| index.due_times.get(a).cmp(&index.due_times.get(b)))
                    .then_with(|| index.created_times.get(a).cmp(&index.created_times.get(b)))
            });
        }
    }
}

fn priority_score(id: &Uuid, index: &Index, priority_order: &[String]) -> i32 {
    if let Some(entry) = index.entries.get(id) {
        for (i, tag) in priority_order.iter().enumerate() {
            if entry.tags.contains(tag) {
                return (priority_order.len() - i) as i32;
            }
        }
    }
    0
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::entry::{Body, Entry};

    fn test_index() -> Index {
        let entries = vec![
            Entry::new(
                "urgent task".into(),
                Body::Empty,
                vec![
                    "urgent".into(),
                    "work".into(),
                    "created/2026-05-20T10:00".into(),
                    "due/2026-06-01".into(),
                ],
            ),
            Entry::new(
                "normal task".into(),
                Body::Empty,
                vec!["life".into(), "created/2026-05-22T10:00".into()],
            ),
            Entry::new(
                "done task".into(),
                Body::Empty,
                vec![
                    "work".into(),
                    "created/2026-05-19T10:00".into(),
                    "done/2026-05-20T10:00".into(),
                ],
            ),
        ];
        let mut idx = Index::new();
        idx.rebuild_from(&entries);
        idx
    }

    #[test]
    fn test_filter_tag_intersection() {
        let idx = test_index();
        let opts = FilterOptions {
            tags_and: vec!["urgent".into(), "work".into()],
            tags_or: vec![],
            tags_not: vec![],
            due_period: None,
            show_done: true,
            only_done: false,
            sort_by: SortMode::Default,
        };
        let ids = opts.apply(&idx);
        assert_eq!(ids.len(), 1);
    }

    #[test]
    fn test_filter_exclude_done_by_default() {
        let idx = test_index();
        let opts = FilterOptions {
            tags_and: vec![],
            tags_or: vec![],
            tags_not: vec![],
            due_period: None,
            show_done: false,
            only_done: false,
            sort_by: SortMode::Default,
        };
        let ids = opts.apply(&idx);
        assert_eq!(ids.len(), 2);
    }
}
