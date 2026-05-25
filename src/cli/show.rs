use crate::api::SiftCore;

pub fn run(core: &SiftCore, id_prefix: String) -> Result<(), Box<dyn std::error::Error>> {
    let Some(entry) = core.get_entry(&id_prefix) else {
        return Err(format!("no entry matching '{id_prefix}'").into());
    };
    println!("ID:   {}", entry.id);
    println!("Name: {}", entry.name);
    println!("Tags: {}", entry.tags.join(", "));
    match &entry.body {
        crate::entry::Body::Text { content } => println!("Body:\n{content}"),
        crate::entry::Body::File { path } => println!("File: {path}"),
        crate::entry::Body::Empty => {}
    }
    Ok(())
}
