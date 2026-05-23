# sift — architecture

Personal entry tag index tool. All organization dimensions are tags. JSONL storage, in-memory index, Rust core.

## File map

```
src/
├── lib.rs              # pub mod re-exports
├── entry.rs            # Entry struct (id, headline, body, tags), serde, normalize
├── config.rs           # XDG paths, TOML load/save, date_prefixes
├── store.rs            # JSONL append, read_all, atomic write_all, update
├── index.rs            # In-memory: tag→ids, tag counts, time extraction
├── filter.rs           # Tag ops (intersect/union/exclude/wildcard), date, sort
├── main.rs             # Binary entry: sift::cli::run()
└── cli/
    ├── mod.rs           # Clap parser, Command enum, dispatch
    ├── add.rs           # sift add <headline> --tag --at --body
    ├── list.rs          # sift list --tag --any --exclude --due --sort --format
    ├── tag_cmd.rs       # sift tag <id> --add --rm --at
    ├── edit.rs          # sift edit <id> --headline --body
    ├── delete.rs        # sift delete <id>
    ├── show.rs          # sift show <id>
    ├── tags_cmd.rs      # sift tags --like
    ├── search_cmd.rs    # sift search <query>
    └── stats.rs         # sift stats
```

## Data flow

```
CLI (clap)
    │
    ▼
cli/*.rs  ──uses──▶  store (JSONL I/O)
    │                   │
    ▼                   ▼
filter ◀──reads──▶  index (in-memory)
    │
    ▼
sorted/filtered Entry list
```

## Entry model

4 fields. Only headline + tags are the primary user concern.

```rust
struct Entry {
    id: Uuid,          // system-generated
    headline: String,  // user, one line
    body: String,      // user, free text (md, plain, anything)
    tags: Vec<String>, // user, sole organization dimension
}
```

Time is expressed via tags with configured prefixes: `created/2026-05-23T10:00`, `done/2026-05-23T12:00`, `due/2026-06-01`.

No database. JSONL is source format and runtime format. 1K–10K entries → < 3MB file → full load + index < 5ms.

## Storage

```
~/.config/sift/config.toml
~/.local/share/sift/entries.jsonl
```

Config defines tag date_prefixes, priority_order (sort weighting), display formats.

## Dev

```bash
nix-shell --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store" shell.nix
cargo build
cargo test
cargo clippy -- -D warnings
```

## Dependencies

serde, serde_json, clap, clap_complete, chrono, uuid, toml, comfy-table, directories
