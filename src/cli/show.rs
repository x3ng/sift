use crate::api::SiftCore;

pub fn run(core: &SiftCore, id_prefix: String) -> Result<(), Box<dyn std::error::Error>> {
    let Some(entry) = core.get_entry(&id_prefix) else {
        return Err(format!("no entry matching '{id_prefix}'").into());
    };
    println!("ID:   {}", entry.id);
    println!("Name: {}", entry.name);
    println!("Tags: {}", entry.tags.join(", "));
    if !entry.value.is_empty() {
        println!("Value:\n{}", entry.value);
    }
    Ok(())
}
