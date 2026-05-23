use crate::store::Store;
use crate::index::Index;
use crate::config::Config;

pub fn run(
    _store: &Store,
    _index: &mut Index,
    _cfg: &Config,
    _id_prefix: String,
    _add: Vec<String>,
    _rm: Vec<String>,
    _at: Vec<String>,
) -> Result<(), Box<dyn std::error::Error>> {
    println!("tag: not yet implemented");
    Ok(())
}
