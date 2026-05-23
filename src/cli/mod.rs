use clap::{Parser, Subcommand};

mod add;
mod delete;
mod edit;
mod list;
mod search_cmd;
mod show;
mod stats;
mod tag_cmd;
mod tags_cmd;

#[derive(Parser)]
#[command(name = "sift", version, about = "Personal entry tag index tool")]
pub struct Cli {
    #[command(subcommand)]
    pub command: Command,
}

#[derive(Subcommand)]
pub enum Command {
    /// Add a new entry
    Add {
        headline: String,
        #[arg(short, long, value_delimiter = ',')]
        tag: Vec<String>,
        #[arg(long, value_delimiter = ',')]
        at: Vec<String>,
        #[arg(short, long)]
        body: Option<String>,
    },
    /// List entries with filtering
    List {
        #[arg(long = "tag", value_delimiter = ',')]
        tags_and: Vec<String>,
        #[arg(long = "any", value_delimiter = ',')]
        tags_or: Vec<String>,
        #[arg(long = "exclude", value_delimiter = ',')]
        tags_not: Vec<String>,
        #[arg(long = "due")]
        due: Option<String>,
        #[arg(long = "sort", default_value = "default")]
        sort: String,
        #[arg(long = "format", default_value = "plain")]
        format: String,
    },
    /// Add or remove tags on an entry
    Tag {
        id_prefix: String,
        #[arg(long, value_delimiter = ',')]
        add: Vec<String>,
        #[arg(long, value_delimiter = ',')]
        rm: Vec<String>,
        #[arg(long, value_delimiter = ',')]
        at: Vec<String>,
    },
    /// Edit an entry's headline or body
    Edit {
        id_prefix: String,
        #[arg(long)]
        headline: Option<String>,
        #[arg(long)]
        body: Option<String>,
    },
    /// Delete an entry permanently
    Delete { id_prefix: String },
    /// Show full entry details
    Show { id_prefix: String },
    /// List all tags with counts
    Tags {
        #[arg(long)]
        like: Option<String>,
    },
    /// Full-text search in headline and body
    Search { query: String },
    /// Show statistics
    Stats,
    /// Generate shell completion script
    Completion {
        /// Shell (bash, zsh, fish)
        shell: String,
    },
}

pub fn run() {
    let cli = Cli::parse();

    use crate::config::Config;
    use crate::index::Index;
    use crate::store::Store;

    let cfg = Config::load().unwrap_or_else(|e| {
        eprintln!("warning: could not load config: {e}, using defaults");
        Config::default_with_paths()
    });

    let store = Store::new(cfg.entries_path(), cfg.backup_dir());

    let entries = store.read_all().unwrap_or_else(|e| {
        eprintln!("error reading entries: {e}");
        vec![]
    });
    let mut index = Index::new();
    index.rebuild_from(&entries);

    let result = match cli.command {
        Command::Add {
            headline,
            tag,
            at,
            body,
        } => add::run(&store, &mut index, &cfg, headline, tag, at, body),
        Command::List {
            tags_and,
            tags_or,
            tags_not,
            due,
            sort,
            format,
        } => list::run(
            &index, &cfg, tags_and, tags_or, tags_not, due, sort, format,
        ),
        Command::Tag {
            id_prefix,
            add,
            rm,
            at,
        } => tag_cmd::run(&store, &mut index, &cfg, id_prefix, add, rm, at),
        Command::Edit {
            id_prefix,
            headline,
            body,
        } => edit::run(&store, &mut index, id_prefix, headline, body),
        Command::Delete { id_prefix } => delete::run(&store, &mut index, id_prefix),
        Command::Show { id_prefix } => show::run(&index, id_prefix),
        Command::Tags { like } => tags_cmd::run(&index, like),
        Command::Search { query } => search_cmd::run(&index, query),
        Command::Stats => stats::run(&index),
        Command::Completion { shell } => {
            use clap::CommandFactory;
            use clap_complete::{
                generate,
                shells::{Bash, Fish, Zsh},
            };
            let mut cmd = Cli::command();
            match shell.as_str() {
                "bash" => generate(Bash, &mut cmd, "sift", &mut std::io::stdout()),
                "zsh" => generate(Zsh, &mut cmd, "sift", &mut std::io::stdout()),
                "fish" => generate(Fish, &mut cmd, "sift", &mut std::io::stdout()),
                _ => eprintln!("unknown shell: {shell}. supported: bash, zsh, fish"),
            }
            Ok(())
        }
    };

    if let Err(e) = result {
        eprintln!("error: {e}");
        std::process::exit(1);
    }
}
