use crate::config::Config;
use crate::entry::Entry;
use crate::index::Index;
use crate::store::Store;
use chrono::Local;

pub fn run(
    store: &Store,
    index: &mut Index,
    _cfg: &Config,
    headline: String,
    tag: Vec<String>,
    at: Vec<String>,
    body: Option<String>,
) -> Result<(), Box<dyn std::error::Error>> {
    let mut tags = tag;

    for spec in &at {
        if let Some((key, value)) = spec.split_once('=') {
            let prefix = if key.ends_with('/') {
                key.to_string()
            } else {
                format!("{key}/")
            };
            let ts = resolve_time_spec(value)?;
            tags.push(format!("{prefix}{ts}"));
        } else {
            let prefix = if spec.ends_with('/') {
                spec.clone()
            } else {
                format!("{spec}/")
            };
            let ts = Local::now().format("%Y-%m-%dT%H:%M").to_string();
            tags.push(format!("{prefix}{ts}"));
        }
    }

    let entry = Entry::new(headline, body.unwrap_or_default(), tags);
    store.append(&entry)?;
    let id_prefix = entry.id_prefix();
    index.add_entry(entry);

    println!("{id_prefix}");
    Ok(())
}

fn resolve_time_spec(spec: &str) -> Result<String, Box<dyn std::error::Error>> {
    let now = Local::now().naive_local();
    match spec {
        "now" | "today" => Ok(now.format("%Y-%m-%dT%H:%M").to_string()),
        "tomorrow" => {
            let t = now + chrono::Duration::days(1);
            Ok(t.format("%Y-%m-%dT%H:%M").to_string())
        }
        "friday" => {
            use chrono::Datelike;
            let days_until_fri = (5i64 - now.weekday().num_days_from_monday() as i64 + 7) % 7;
            let days = if days_until_fri == 0 {
                7
            } else {
                days_until_fri
            };
            let t = now + chrono::Duration::days(days);
            Ok(t.format("%Y-%m-%d").to_string())
        }
        s if s.contains('-') || s.contains('.') => Ok(s.replace('.', "-")),
        _ => Err(format!("unknown time spec: {spec}").into()),
    }
}
