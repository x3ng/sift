use crate::engine::index::Index;
use crate::io::store::Store;
use uuid::Uuid;

pub fn run(
    store: &Store,
    index: &mut Index,
    id_prefix: String,
    headline: Option<String>,
    body: Option<String>,
) -> Result<(), Box<dyn std::error::Error>> {
    let id = resolve_id(index, &id_prefix)?;

    if headline.is_none() && body.is_none() {
        return Err("use --headline or --body to specify what to edit".into());
    }

    if let Some(h) = headline {
        store.update(&id, |entry| entry.headline = h)?;
    }
    if let Some(b) = body {
        store.update(&id, |entry| entry.body = b)?;
    }

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
