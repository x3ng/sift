use crate::filter::{DuePeriod, FilterOptions, SortMode};
use crate::index::Index;
use crate::store::Store;
use chrono::Local;
use chrono::NaiveDate;
use uuid::Uuid;

#[allow(clippy::too_many_arguments)]
pub fn run(
    store: &Store,
    index: &mut Index,
    _cfg: &crate::config::Config,
    tags_and: Vec<String>,
    tags_or: Vec<String>,
    tags_not: Vec<String>,
    due: Option<String>,
    add_tags: Vec<String>,
    rm_tags: Vec<String>,
    delete: bool,
) -> Result<(), Box<dyn std::error::Error>> {
    // Apply filters to find matching entries
    let due_period = match due.as_deref() {
        Some("today") => Some(DuePeriod::Today),
        Some("this-week") => Some(DuePeriod::ThisWeek),
        Some("overdue") => Some(DuePeriod::Overdue),
        Some(s) => NaiveDate::parse_from_str(s, "%Y-%m-%d")
            .ok()
            .map(DuePeriod::Before),
        None => None,
    };

    let opts = FilterOptions {
        tags_and, tags_or, tags_not,
        due_period,
        show_done: true,
        only_done: false,
        sort_by: SortMode::Default,
    };

    let ids = opts.apply(index);
    if ids.is_empty() {
        println!("no entries match the filter");
        return Ok(());
    }

    if delete {
        let mut entries = store.read_all()?;
        let id_set: std::collections::HashSet<Uuid> = ids.iter().copied().collect();
        entries.retain(|e| !id_set.contains(&e.id));
        store.write_all(&entries)?;
        index.rebuild_from(&entries);
        println!("deleted {} entries", ids.len());
        return Ok(());
    }

    // Add/remove tags
    let mut entries = store.read_all()?;
    let now = Local::now().format("%Y-%m-%dT%H:%M").to_string();
    let mut modified = 0;

    for entry in &mut entries {
        if !ids.contains(&entry.id) { continue; }
        modified += 1;

        for tag in &add_tags {
            let clean = tag.trim().trim_start_matches('#');
            if clean == "done" {
                // Special: "done" adds timed done/ tag
                let done_tag = format!("done/{now}");
                if !entry.tags.contains(&done_tag) {
                    entry.tags.push(done_tag);
                }
            } else if !entry.tags.iter().any(|t| t == clean) {
                entry.tags.push(clean.to_string());
            }
        }
        for pattern in &rm_tags {
            if pattern.ends_with('*') {
                let prefix = pattern.trim_end_matches('*');
                entry.tags.retain(|t| !t.starts_with(prefix));
            } else {
                let clean = pattern.trim().trim_start_matches('#');
                let clean_str = clean.to_string();
                entry.tags.retain(|t| t != &clean_str);
            }
        }
        entry.tags.sort();
        entry.tags.dedup();
    }

    store.write_all(&entries)?;
    index.rebuild_from(&entries);
    println!("modified {modified} entries");
    Ok(())
}
