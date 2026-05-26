use crate::api::SiftCore;

pub fn run(core: &SiftCore, query: String) -> Result<(), Box<dyn std::error::Error>> {
    let entries = core.search(query.clone());
    if entries.is_empty() {
        println!("(no matches)");
        return Ok(());
    }
    for entry in &entries {
        println!("{}  {}", entry.id_prefix(), entry.name);
        if entry.value.to_lowercase().contains(&query.to_lowercase()) {
            let preview: String = entry.value.chars().take(80).collect();
            println!("         body: {preview}");
        }
    }
    Ok(())
}
