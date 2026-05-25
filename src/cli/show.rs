use crate::engine::index::Index;
use uuid::Uuid;

pub fn run(index: &Index, id_prefix: String) -> Result<(), Box<dyn std::error::Error>> {
    let id = resolve_id(index, &id_prefix)?;
    let entry = index.entries.get(&id).ok_or("entry not found")?;

    println!("ID:   {}", entry.id);
    println!("Name: {}", entry.name);
    println!("Tags: {}", entry.tags.join(", "));
    match &entry.body {
        crate::entry::Body::Text { content } => {
            println!("Body:\n{content}");
        }
        crate::entry::Body::File { path } => {
            println!("File: {path}");
        }
        crate::entry::Body::Empty => {}
    }
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
