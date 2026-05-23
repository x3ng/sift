use crate::index::Index;

pub fn run(index: &Index, like: Option<String>) -> Result<(), Box<dyn std::error::Error>> {
    let tags = index.all_tags();
    let filtered: Vec<_> = if let Some(pattern) = &like {
        if pattern.ends_with('*') {
            let prefix = pattern.trim_end_matches('*');
            tags.into_iter()
                .filter(|(t, _)| t.starts_with(prefix))
                .collect()
        } else {
            tags.into_iter()
                .filter(|(t, _)| t.contains(pattern.as_str()))
                .collect()
        }
    } else {
        tags
    };

    if filtered.is_empty() {
        println!("(no tags)");
        return Ok(());
    }

    for (tag, count) in &filtered {
        println!("{:>5}  #{}", count, tag);
    }
    Ok(())
}
