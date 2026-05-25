use crate::api::SiftCore;

pub fn run(core: &SiftCore) -> Result<(), Box<dyn std::error::Error>> {
    let s = core.stats();
    println!("Total entries:  {}", s.total);
    println!("Active:         {}", s.active);
    println!("Done:           {}", s.done);
    println!("Unique tags:    {}", s.unique_tags);

    let tags = core.all_tags();
    if !tags.is_empty() {
        println!("\nTop tags:");
        for (tag, count) in tags.iter().take(10) {
            println!("  {:>5}  #{}", count, tag);
        }
    }
    Ok(())
}
