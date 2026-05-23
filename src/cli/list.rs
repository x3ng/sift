use crate::config::Config;
use crate::filter::{self, DuePeriod, FilterOptions, SortMode};
use crate::index::Index;
use chrono::NaiveDate;
use comfy_table::Table;
use serde_json;

#[allow(clippy::too_many_arguments)]
pub fn run(
    index: &Index,
    cfg: &Config,
    tags_and: Vec<String>,
    tags_or: Vec<String>,
    tags_not: Vec<String>,
    due: Option<String>,
    done: bool,
    all: bool,
    sort: String,
    format: String,
) -> Result<(), Box<dyn std::error::Error>> {
    let due_period = match due.as_deref() {
        Some("today") => Some(DuePeriod::Today),
        Some("tomorrow") => Some(DuePeriod::Tomorrow),
        Some("this-week") => Some(DuePeriod::ThisWeek),
        Some("overdue") => Some(DuePeriod::Overdue),
        Some(s) => {
            let date = NaiveDate::parse_from_str(s, "%Y-%m-%d")
                .or_else(|_| NaiveDate::parse_from_str(s, "%Y.%m.%d"))
                .ok();
            date.map(DuePeriod::Before)
        }
        None => None,
    };

    let sort_mode = match sort.as_str() {
        "created" => SortMode::Created,
        "due" => SortMode::Due,
        _ => SortMode::Default,
    };

    let opts = FilterOptions {
        tags_and,
        tags_or,
        tags_not,
        due_period,
        show_done: all,
        only_done: done && !all,
        sort_by: sort_mode,
    };

    let mut ids = opts.apply(index);
    filter::sort_ids(&mut ids, index, &opts.sort_by, &cfg.tags.priority_order);

    match format.as_str() {
        "json" => {
            let entries: Vec<_> = ids.iter().filter_map(|id| index.entries.get(id)).collect();
            println!("{}", serde_json::to_string_pretty(&entries)?);
        }
        "jsonl" => {
            for id in &ids {
                if let Some(entry) = index.entries.get(id) {
                    println!("{}", serde_json::to_string(entry)?);
                }
            }
        }
        _ => {
            if ids.is_empty() {
                println!("(no entries)");
                return Ok(());
            }
            let mut table = Table::new();
            table.set_header(vec!["ID", "Headline", "Tags", "Due"]);
            for id in &ids {
                if let Some(entry) = index.entries.get(id) {
                    let tags_str = entry
                        .tags
                        .iter()
                        .filter(|t| !t.starts_with("created/") && !t.starts_with("done/"))
                        .map(|t| format!("#{t}"))
                        .collect::<Vec<_>>()
                        .join(" ");
                    let due_str = index
                        .due_times
                        .get(id)
                        .map(|dt| dt.format(&cfg.display.date_format).to_string())
                        .unwrap_or_default();
                    table.add_row(vec![
                        entry.id_prefix(),
                        entry.headline.clone(),
                        tags_str,
                        due_str,
                    ]);
                }
            }
            println!("{table}");
        }
    }
    Ok(())
}
