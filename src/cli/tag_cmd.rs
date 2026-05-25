use crate::api::SiftCore;
use chrono::Local;

pub fn run(
    core: &mut SiftCore,
    id_prefix: String,
    add: Vec<String>,
    rm: Vec<String>,
    at: Vec<String>,
) -> Result<(), Box<dyn std::error::Error>> {
    let mut add_tags = add;
    for spec in &at {
        let ts = Local::now().format("%Y-%m-%dT%H:%M").to_string();
        let prefix = if spec.ends_with('/') { spec.clone() } else { format!("{spec}/") };
        add_tags.push(format!("{prefix}{ts}"));
    }
    core.tag(id_prefix.clone(), add_tags, rm)?;
    println!("{id_prefix}");
    Ok(())
}
