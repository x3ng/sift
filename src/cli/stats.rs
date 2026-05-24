use crate::engine::index::Index;

pub fn run(index: &Index) -> Result<(), Box<dyn std::error::Error>> {
    let total = index.entries.len();
    let active = index.entries.values().filter(|e| !e.is_done()).count();
    let done = total - active;
    let unique_tags = index.tag_counts.len();

    println!("Total entries:  {total}");
    println!("Active:         {active}");
    println!("Done:           {done}");
    println!("Unique tags:    {unique_tags}");

    if !index.tag_counts.is_empty() {
        println!("\nTop tags:");
        let mut tags = index.all_tags();
        tags.truncate(10);
        for (tag, count) in &tags {
            println!("  {:>5}  #{}", count, tag);
        }
    }
    Ok(())
}
