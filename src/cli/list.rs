use crate::api::SiftCore;
use comfy_table::Table;

#[allow(clippy::too_many_arguments)]
pub fn run(
    core: &SiftCore,
    tags_and: Vec<String>,
    tags_or: Vec<String>,
    tags_not: Vec<String>,
    due: Option<String>,
    query: Option<String>,
    sort: String,
    format: String,
) -> Result<(), Box<dyn std::error::Error>> {
    let entries = if let Some(q) = query {
        core.list_parsed(&q, true)?
    } else {
        core.list(tags_and, tags_or, tags_not, due, true, sort)?
    };

    match format.as_str() {
        "json" => {
            println!("{}", serde_json::to_string_pretty(&entries)?);
        }
        "jsonl" => {
            for entry in &entries {
                println!("{}", serde_json::to_string(entry)?);
            }
        }
        _ => {
            if entries.is_empty() {
                println!("(no entries)");
                return Ok(());
            }
            let mut table = Table::new();
            table.set_header(vec!["ID", "Name", "Tags"]);
            for entry in &entries {
                let tags_str = entry.tags.iter()
                    .map(|t| format!("#{t}"))
                    .collect::<Vec<_>>()
                    .join(" ");
                table.add_row(vec![
                    entry.id_prefix(),
                    entry.name.clone(),
                    tags_str,
                ]);
            }
            println!("{table}");
        }
    }
    Ok(())
}
