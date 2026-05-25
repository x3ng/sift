use crate::api::SiftCore;

pub fn run(core: &mut SiftCore, id_prefix: String) -> Result<(), Box<dyn std::error::Error>> {
    // Get name before deleting
    let name = core.get_entry(&id_prefix).map(|e| e.name.clone())
        .unwrap_or_else(|| id_prefix.clone());
    core.delete(id_prefix)?;
    println!("deleted: {name}");
    Ok(())
}
