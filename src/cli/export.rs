use crate::io::store::Store;
use std::fs;
use std::io::Write;

pub fn run(store: &Store, path: &str, format: &str) -> Result<(), Box<dyn std::error::Error>> {
    let entries = store.read_all()?;

    match format {
        "jsonl" => {
            let mut f = fs::File::create(path)?;
            for e in &entries {
                writeln!(f, "{}", serde_json::to_string(e)?)?;
            }
        }
        "json" => {
            let json = serde_json::to_string_pretty(&entries)?;
            fs::write(path, json)?;
        }
        "md" => {
            let mut f = fs::File::create(path)?;
            for e in &entries {
                let status = if e.is_done() { "x" } else { " " };
                let tags = e.tags.iter()
                    .map(|t| format!("#{t}"))
                    .collect::<Vec<_>>()
                    .join(" ");
                writeln!(f, "- [{status}] {}  {tags}", e.name)?;
                if let Some(text) = e.body.text() {
                    writeln!(f, "  {text}")?;
                }
            }
        }
        _ => return Err(format!("unknown format: {format}. supported: jsonl, json, md").into()),
    }

    println!("exported {} entries to {path}", entries.len());
    Ok(())
}
