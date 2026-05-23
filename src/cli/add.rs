use crate::store::Store;
use crate::index::Index;
use crate::config::Config;

pub fn run(
    _store: &Store,
    _index: &mut Index,
    _cfg: &Config,
    _headline: String,
    _tag: Vec<String>,
    _at: Vec<String>,
    _body: Option<String>,
) -> Result<(), Box<dyn std::error::Error>> {
    println!("add: not yet implemented");
    Ok(())
}
