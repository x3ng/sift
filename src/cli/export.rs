use crate::api::SiftCore;
use std::fs;
use std::io::Write;

pub fn run(core: &SiftCore, path: &str, format: &str) -> Result<(), Box<dyn std::error::Error>> {
    if format == "jsonl" {
        return core.export_to(path.into()).map_err(|e| e.into());
    }

    let entries = core.store.read_all()?;

    match format {
        "json" => {
            let json = serde_json::to_string_pretty(&entries)?;
            fs::write(path, json)?;
        }
        "md" => {
            let mut f = fs::File::create(path)?;
            for e in &entries {
                let status = if e.is_done() { "x" } else { " " };
                let tags = e.tags.iter().map(|t| format!("#{t}")).collect::<Vec<_>>().join(" ");
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
