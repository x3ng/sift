use crate::engine::index::Index;

pub fn run(index: &Index, query: String) -> Result<(), Box<dyn std::error::Error>> {
    let query_lower = query.to_lowercase();
    let mut matches: Vec<_> = index
        .entries
        .values()
        .filter(|e| {
            e.name.to_lowercase().contains(&query_lower)
                || e.body.searchable_text().to_lowercase().contains(&query_lower)
                || e.tags
                    .iter()
                    .any(|t| t.to_lowercase().contains(&query_lower))
        })
        .collect();

    matches.sort_by_key(|e| e.name.clone());

    if matches.is_empty() {
        println!("(no matches)");
        return Ok(());
    }

    for entry in &matches {
        println!("{}  {}", entry.id_prefix(), entry.name);
        let body_text = entry.body.searchable_text();
        if body_text.to_lowercase().contains(&query_lower) {
            let preview: String = body_text.chars().take(80).collect();
            println!("         body: {preview}");
        }
    }
    Ok(())
}
