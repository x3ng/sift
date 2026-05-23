use crate::index::Index;
use crate::config::Config;

pub fn run(
    _index: &Index,
    _cfg: &Config,
    _tags_and: Vec<String>,
    _tags_or: Vec<String>,
    _tags_not: Vec<String>,
    _due: Option<String>,
    _done: bool,
    _all: bool,
    _sort: String,
    _format: String,
) -> Result<(), Box<dyn std::error::Error>> {
    println!("list: not yet implemented");
    Ok(())
}
