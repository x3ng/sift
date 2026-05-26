use crate::api::SiftCore;

#[allow(clippy::too_many_arguments)]
pub fn run(
    core: &mut SiftCore,
    tags_and: Vec<String>,
    tags_or: Vec<String>,
    tags_not: Vec<String>,
    due: Option<String>,
    add_tags: Vec<String>,
    rm_tags: Vec<String>,
    delete: bool,
) -> Result<(), Box<dyn std::error::Error>> {
    // Use SiftCore::list for filtering
    let entries = core.list(tags_and, tags_or, tags_not, due, true, "default".into())?;
    if entries.is_empty() {
        println!("no entries match the filter");
        return Ok(());
    }

    let prefixes: Vec<String> = entries.iter().map(|e| e.id_prefix()).collect();

    if delete {
        let count = core.batch_delete(prefixes)?;
        println!("deleted {count} entries");
    } else {
        let count = core.batch_tag(prefixes, add_tags, rm_tags)?;
        println!("modified {count} entries");
    }
    Ok(())
}
