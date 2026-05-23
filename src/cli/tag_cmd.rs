use crate::config::Config;
use crate::index::Index;
use crate::store::Store;
use chrono::Local;
use uuid::Uuid;

pub fn run(
    store: &Store,
    index: &mut Index,
    _cfg: &Config,
    id_prefix: String,
    add: Vec<String>,
    rm: Vec<String>,
    at: Vec<String>,
) -> Result<(), Box<dyn std::error::Error>> {
    let id = resolve_id(index, &id_prefix)?;

    let mut timed_tags = Vec::new();
    for spec in &at {
        let ts = Local::now().format("%Y-%m-%dT%H:%M").to_string();
        let prefix = if spec.ends_with('/') {
            spec.clone()
        } else {
            format!("{spec}/")
        };
        timed_tags.push(format!("{prefix}{ts}"));
    }

    store.update(&id, |entry| {
        for tag in &add {
            let clean = tag.trim().trim_start_matches('#');
            if !entry.tags.contains(&clean.to_string()) {
                entry.tags.push(clean.to_string());
            }
        }
        for tag in &timed_tags {
            if !entry.tags.contains(tag) {
                entry.tags.push(tag.clone());
            }
        }
        for pattern in &rm {
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
    })?;

    let entries = store.read_all()?;
    index.rebuild_from(&entries);

    println!("{}", id_prefix);
    Ok(())
}

fn resolve_id(index: &Index, prefix: &str) -> Result<Uuid, Box<dyn std::error::Error>> {
    let matches: Vec<Uuid> = index
        .entries
        .keys()
        .filter(|id| id.to_string().starts_with(prefix))
        .copied()
        .collect();
    match matches.len() {
        0 => Err(format!("no entry matching '{prefix}'").into()),
        1 => Ok(matches[0]),
        n => Err(format!("{n} entries match '{prefix}', be more specific").into()),
    }
}
