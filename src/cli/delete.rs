use crate::index::Index;
use crate::store::Store;
use uuid::Uuid;

pub fn run(
    store: &Store,
    index: &mut Index,
    id_prefix: String,
) -> Result<(), Box<dyn std::error::Error>> {
    let id = resolve_id(index, &id_prefix)?;
    let headline = index.entries.get(&id).map(|e| e.headline.clone())
        .ok_or("entry not found")?;

    let mut entries = store.read_all()?;
    entries.retain(|e| e.id != id);
    store.write_all(&entries)?;

    index.rebuild_from(&entries);

    println!("deleted: {headline}");
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
