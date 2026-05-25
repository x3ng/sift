use crate::config::Config;
use crate::engine::combinator::{self, parse_query};
use crate::engine::filter::{self, DateFilter, DateOp, FilterOptions, SortMode};
use crate::engine::index::Index;
use comfy_table::Table;
use serde_json;

pub fn run(
    index: &Index,
    cfg: &Config,
    tags_and: Vec<String>,
    tags_or: Vec<String>,
    tags_not: Vec<String>,
    due: Option<String>,
    query: Option<String>,
    sort: String,
    format: String,
) -> Result<(), Box<dyn std::error::Error>> {
    let mut alternatives: Vec<crate::engine::combinator::ParsedQuery> = vec![];

    let (tags_and, tags_or, tags_not, date_filters, sort_mode) = if let Some(q) = query {
        let pq = parse_query(&q);
        alternatives = pq.alternatives.clone();
        let df: Vec<DateFilter> = pq.dates.iter().map(|dc| {
            let op = match dc.op {
                combinator::DateOp::Today => DateOp::Today,
                combinator::DateOp::Yesterday => DateOp::Yesterday,
                combinator::DateOp::Tomorrow => DateOp::Tomorrow,
                combinator::DateOp::ThisWeek => DateOp::ThisWeek,
                combinator::DateOp::LastWeek => DateOp::LastWeek,
                combinator::DateOp::NextWeek => DateOp::NextWeek,
                combinator::DateOp::ThisMonth => DateOp::ThisMonth,
                combinator::DateOp::LastMonth => DateOp::LastMonth,
                combinator::DateOp::Overdue => DateOp::Overdue,
            };
            DateFilter { prefix: dc.prefix.clone(), op }
        }).collect();
        let sm = match pq.sort_by {
            Some(combinator::SortDirective::Due) => SortMode::Due,
            Some(combinator::SortDirective::Created) => SortMode::Created,
            None => SortMode::Default,
        };
        (pq.tags_and, pq.tags_or, pq.tags_not, df, sm)
    } else {
        let df = match due.as_deref() {
            Some("today") => vec![DateFilter { prefix: "due".into(), op: DateOp::Today }],
            Some("tomorrow") => vec![DateFilter { prefix: "due".into(), op: DateOp::Tomorrow }],
            Some("this-week") => vec![DateFilter { prefix: "due".into(), op: DateOp::ThisWeek }],
            Some("overdue") => vec![DateFilter { prefix: "due".into(), op: DateOp::Overdue }],
            Some(_) => return Err("specific dates not supported via --due; use a period name".into()),
            None => vec![],
        };
        let sm = match sort.as_str() {
            "created" => SortMode::Created,
            "due" => SortMode::Due,
            _ => SortMode::Default,
        };
        (tags_and, tags_or, tags_not, df, sm)
    };

    let opts = FilterOptions {
        tags_and,
        tags_or,
        tags_not,
        date_filters,
        show_done: true,
        only_done: false,
        sort_by: sort_mode,
    };

    let mut ids = opts.apply(index);

    // Union with | alternatives
    for alt in &alternatives {
        let alt_df: Vec<DateFilter> = alt.dates.iter().map(|dc| {
            let op = match dc.op {
                combinator::DateOp::Today => DateOp::Today,
                combinator::DateOp::Yesterday => DateOp::Yesterday,
                combinator::DateOp::Tomorrow => DateOp::Tomorrow,
                combinator::DateOp::ThisWeek => DateOp::ThisWeek,
                combinator::DateOp::LastWeek => DateOp::LastWeek,
                combinator::DateOp::NextWeek => DateOp::NextWeek,
                combinator::DateOp::ThisMonth => DateOp::ThisMonth,
                combinator::DateOp::LastMonth => DateOp::LastMonth,
                combinator::DateOp::Overdue => DateOp::Overdue,
            };
            DateFilter { prefix: dc.prefix.clone(), op }
        }).collect();
        let alt_opts = FilterOptions {
            tags_and: alt.tags_and.clone(),
            tags_or: alt.tags_or.clone(),
            tags_not: alt.tags_not.clone(),
            date_filters: alt_df,
            show_done: true,
            only_done: false,
            sort_by: SortMode::Default,
        };
        let alt_ids = alt_opts.apply(index);
        let existing: std::collections::HashSet<_> = ids.iter().copied().collect();
        for id in alt_ids {
            if !existing.contains(&id) { ids.push(id); }
        }
    }

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
            table.set_header(vec!["ID", "Name", "Tags", "Due"]);
            for id in &ids {
                if let Some(entry) = index.entries.get(id) {
                    let tags_str = entry.tags.iter()
                        .map(|t| format!("#{t}"))
                        .collect::<Vec<_>>()
                        .join(" ");
                    let due_str = index.due_times.get(id)
                        .map(|dt| dt.format(&cfg.display.date_format).to_string())
                        .unwrap_or_default();
                    table.add_row(vec![
                        entry.id_prefix(),
                        entry.name.clone(),
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
