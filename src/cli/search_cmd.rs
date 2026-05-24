use crate::engine::index::Index;

pub fn run(index: &Index, query: String) -> Result<(), Box<dyn std::error::Error>> {
    let query_lower = query.to_lowercase();
    let mut matches: Vec<_> = index
        .entries
        .values()
        .filter(|e| {
            e.headline.to_lowercase().contains(&query_lower)
                || e.body.to_lowercase().contains(&query_lower)
                || e.tags
                    .iter()
                    .any(|t| t.to_lowercase().contains(&query_lower))
        })
        .collect();

    matches.sort_by_key(|e| &e.headline);

    if matches.is_empty() {
        println!("(no matches)");
        return Ok(());
    }

    for entry in &matches {
        println!("{}  {}", entry.id_prefix(), entry.headline);
        if entry.body.to_lowercase().contains(&query_lower) {
            let preview: String = entry.body.chars().take(80).collect();
            println!("         body: {preview}");
        }
    }
    Ok(())
}
