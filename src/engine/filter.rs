use crate::engine::index::Index;
use crate::engine::types::{DateOp, parse_date_value, parse_tag_date};
use chrono::{Datelike, Local, NaiveDate};
use std::collections::HashSet;
use uuid::Uuid;

#[derive(Debug, Clone)]
pub struct DateFilter {
    pub prefix: String,  // tag prefix or "*" for any
    pub op: DateOp,
}

pub struct FilterOptions {
    pub tags_and: Vec<String>,
    pub tags_or: Vec<String>,
    pub tags_not: Vec<String>,
    pub date_filters: Vec<DateFilter>,
    pub show_done: bool,
    pub only_done: bool,
    pub sort_by: SortMode,
}

#[derive(Debug, Clone, Copy, PartialEq)]
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

        // Date filters
        if !self.date_filters.is_empty() {
            let today = Local::now().date_naive();
            ids.retain(|id| {
                let Some(entry) = index.entries.get(id) else { return false; };

                // For each date filter, check if any matching tag satisfies the period
                self.date_filters.iter().all(|df| {
                    let match_date = |tag: &str, prefix: &str| -> Option<NaiveDate> {
                        parse_tag_date(tag, &format!("{prefix}/")).map(|dt| dt.date())
                    };

                    let matches_period = |d: NaiveDate| match df.op {
                        DateOp::Today => d == today,
                        DateOp::Yesterday => d == today - chrono::Duration::days(1),
                        DateOp::Tomorrow => d == today + chrono::Duration::days(1),
                        DateOp::ThisWeek => {
                            let wday = today.weekday().num_days_from_monday() as i64;
                            let week_start = today - chrono::Duration::days(wday);
                            let week_end = week_start + chrono::Duration::days(6);
                            d >= week_start && d <= week_end
                        }
                        DateOp::LastWeek => {
                            let wday = today.weekday().num_days_from_monday() as i64;
                            let this_monday = today - chrono::Duration::days(wday);
                            let last_monday = this_monday - chrono::Duration::days(7);
                            let last_sunday = this_monday - chrono::Duration::days(1);
                            d >= last_monday && d <= last_sunday
                        }
                        DateOp::NextWeek => {
                            let wday = today.weekday().num_days_from_monday() as i64;
                            let this_monday = today - chrono::Duration::days(wday);
                            let next_monday = this_monday + chrono::Duration::days(7);
                            let next_sunday = next_monday + chrono::Duration::days(6);
                            d >= next_monday && d <= next_sunday
                        }
                        DateOp::ThisMonth => {
                            d.year() == today.year() && d.month() == today.month()
                        }
                        DateOp::LastMonth => {
                            let prev = if today.month() == 1 {
                                chrono::NaiveDate::from_ymd_opt(today.year() - 1, 12, 1).unwrap()
                            } else {
                                chrono::NaiveDate::from_ymd_opt(today.year(), today.month() - 1, 1).unwrap()
                            };
                            d.year() == prev.year() && d.month() == prev.month()
                        }
                        DateOp::Overdue => d < today,
                    };

                    if df.prefix == "*" {
                        // Match any tag that has a parseable date after '/'
                        entry.tags.iter().any(|t| {
                            t.find('/').and_then(|pos| parse_date_value(&t[pos + 1..]))
                                .is_some_and(|dt| matches_period(dt.date()))
                        })
                    } else {
                        entry.tags.iter().any(|t| {
                            match_date(t, &df.prefix).is_some_and(&matches_period)
                        })
                    }
                })
            });
        }

        ids.into_iter().collect()
    }
}

fn resolve_tag_pattern(pattern: &str, index: &Index) -> Vec<String> {
    if !pattern.contains('*') && !pattern.contains('?') {
        // Exact match, no glob
        return vec![pattern.to_string()];
    }
    index
        .tag_counts
        .keys()
        .filter(|t| glob_match(pattern, t))
        .cloned()
        .collect()
}

/// Glob matching: `*` = any chars except `/`, `**` = any chars including `/`, `?` = one char.
fn glob_match(pattern: &str, text: &str) -> bool {
    let p = pattern.as_bytes();
    let t = text.as_bytes();
    glob_rec(p, t)
}

fn glob_rec(p: &[u8], t: &[u8]) -> bool {
    if p.is_empty() {
        return t.is_empty();
    }
    // Check for ** first
    if p.len() >= 2 && p[0] == b'*' && p[1] == b'*' {
        let rest = &p[2..];
        // ** can match zero or more chars (including /)
        for i in 0..=t.len() {
            if glob_rec(rest, &t[i..]) {
                return true;
            }
        }
        return false;
    }
    if p[0] == b'*' {
        let rest = &p[1..];
        // * matches zero or more chars except /
        for i in 0..=t.len() {
            if i > 0 && t[i - 1] == b'/' {
                break; // * cannot cross /
            }
            if glob_rec(rest, &t[i..]) {
                return true;
            }
        }
        return false;
    }
    if p[0] == b'?' {
        // ? matches one char (not /)
        if t.is_empty() || t[0] == b'/' {
            return false;
        }
        return glob_rec(&p[1..], &t[1..]);
    }
    // Literal match
    if t.is_empty() || p[0] != t[0] {
        return false;
    }
    glob_rec(&p[1..], &t[1..])
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
                    e.tags.iter().find_map(|t| parse_tag_date(t, "modified/"))
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
    use crate::entry::Entry;
    use std::collections::HashMap;

    fn test_index() -> Index {
        let entries = vec![
            Entry::new(
                "urgent task".into(),
                String::new(),
                vec![
                    "urgent".into(),
                    "work".into(),
                    "created/2026-05-20T10:00".into(),
                    "due/2026-06-01".into(),
                ],
            ),
            Entry::new(
                "normal task".into(),
                String::new(),
                vec!["life".into(), "created/2026-05-22T10:00".into()],
            ),
            Entry::new(
                "done task".into(),
                String::new(),
                vec![
                    "work".into(),
                    "created/2026-05-19T10:00".into(),
                    "done/2026-05-20T10:00".into(),
                ],
            ),
        ];
        let mut idx = Index::new();
        let prefixes: HashMap<String, String> = HashMap::new();
        idx.rebuild_from(&entries, &prefixes);
        idx
    }

    #[test]
    fn test_filter_tag_intersection() {
        let idx = test_index();
        let opts = FilterOptions {
            tags_and: vec!["urgent".into(), "work".into()],
            tags_or: vec![],
            tags_not: vec![],
            date_filters: vec![],
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
            date_filters: vec![],
            show_done: false,
            only_done: false,
            sort_by: SortMode::Default,
        };
        let ids = opts.apply(&idx);
        assert_eq!(ids.len(), 2);
    }

    #[test]
    fn test_glob_match() {
        assert!(glob_match("work/*", "work/urgent"));
        assert!(glob_match("work/*", "work/design"));
        assert!(!glob_match("work/*", "life/urgent"));
        assert!(!glob_match("work/*", "work/a/b")); // * doesn't cross /

        assert!(glob_match("*/urgent", "work/urgent"));
        assert!(glob_match("*/urgent", "design/urgent"));

        assert!(!glob_match("*due*", "due/2026")); // * doesn't cross /
        assert!(glob_match("*due*", "my-due-date"));
        assert!(!glob_match("*due*", "work"));
        assert!(glob_match("**due**", "due/2026")); // ** crosses /

        assert!(glob_match("work/**", "work/a/b/c")); // ** crosses /
        assert!(glob_match("work/**/urgent", "work/design/urgent"));
        assert!(glob_match("work/**/urgent", "work/a/b/urgent"));

        assert!(glob_match("work/?-fix", "work/a-fix"));
        assert!(!glob_match("work/?-fix", "work/ab-fix"));
    }
}
