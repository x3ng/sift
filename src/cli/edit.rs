use crate::config::Config;
use crate::engine::index::Index;
use crate::entry::Body;
use crate::io::store::Store;
use uuid::Uuid;

pub fn run(
    store: &Store,
    index: &mut Index,
    cfg: &Config,
    id_prefix: String,
    name: Option<String>,
    body: Option<String>,
) -> Result<(), Box<dyn std::error::Error>> {
    let id = resolve_id(index, &id_prefix)?;

    if name.is_none() && body.is_none() {
        return Err("use --name or --body to specify what to edit".into());
    }

    if let Some(n) = name {
        store.update(&id, |entry| entry.name = n)?;
    }
    if let Some(b) = body {
        store.update(&id, |entry| entry.body = Body::Text { content: b })?;
    }

    let entries = store.read_all()?;
    index.rebuild_from(&entries, &cfg.tags.date_prefixes);

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
