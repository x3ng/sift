use crate::api::SiftCore;

pub fn run(core: &SiftCore, query: String) -> Result<(), Box<dyn std::error::Error>> {
    let entries = core.search(query.clone());
    if entries.is_empty() {
        println!("(no matches)");
        return Ok(());
    }
    for entry in &entries {
        println!("{}  {}", entry.id_prefix(), entry.name);
        let body_text = entry.body.searchable_text();
        if body_text.to_lowercase().contains(&query.to_lowercase()) {
            let preview: String = body_text.chars().take(80).collect();
            println!("         body: {preview}");
        }
    }
    Ok(())
}
