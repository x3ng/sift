use crate::store::Store;
use crate::index::Index;

pub fn run(
    _store: &Store,
    _index: &mut Index,
    _id_prefix: String,
    _headline: Option<String>,
    _body: Option<String>,
) -> Result<(), Box<dyn std::error::Error>> {
    println!("edit: not yet implemented");
    Ok(())
}
