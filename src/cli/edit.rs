use crate::api::SiftCore;
use crate::entry::Body;

pub fn run(
    core: &mut SiftCore,
    id_prefix: String,
    name: Option<String>,
    body: Option<String>,
) -> Result<(), Box<dyn std::error::Error>> {
    if name.is_none() && body.is_none() {
        return Err("use --name or --body to specify what to edit".into());
    }
    let b = body.map(|s| Body::Text { content: s });
    core.edit(id_prefix.clone(), name, b)?;
    println!("{id_prefix}");
    Ok(())
}
