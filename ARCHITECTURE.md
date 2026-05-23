# sift — architecture

Personal entry tag index tool. All organization dimensions are tags — no priority enum, no status field, no hierarchy.

## Data model

```rust
struct Entry {
    id: Uuid,            // system
    headline: String,    // user: one line
    body: String,        // user: free text (md, plain, anything)
    tags: Vec<String>,   // user: sole organization dimension
}
```

Time via tags: `created/2026-05-23T10:00`, `done/2026-05-23T12:00`, `due/2026-06-01`.
Config at `~/.config/sift/config.toml` defines which prefixes are date-typed.

Storage: single JSONL file at `~/.local/share/sift/entries.jsonl`. No database.

## File map

```
src/
├── lib.rs            # pub mod re-exports
├── entry.rs          # Entry struct, serde, tag normalize
├── config.rs         # XDG, TOML, date_prefixes
├── store.rs          # JSONL append/read/write/update
├── index.rs          # In-memory: tag→ids, times, counts
├── filter.rs         # Tag ops (and/or/not/*), date sort
├── api.rs            # SiftCore: unified API for FFI
├── main.rs           # Binary: sift::cli::run()
└── cli/
    ├── mod.rs         # Clap: add/list/tag/edit/delete/show/tags/search/stats
    ├── add.rs         # sift add --tag --at --body
    ├── list.rs        # sift list --tag --any --exclude --due --sort
    ├── tag_cmd.rs     # sift tag <id> --add --rm --at
    ├── edit.rs        # sift edit <id> --headline --body
    ├── delete.rs      # sift delete <id>
    ├── show.rs        # sift show <id>
    ├── tags_cmd.rs    # sift tags --like
    ├── search_cmd.rs  # sift search <query>
    └── stats.rs       # sift stats

flutter/              # Flutter cross-platform GUI
├── lib/
│   ├── main.dart
│   └── src/
│       ├── services/
│       │   ├── api.dart     # SiftService: Dart JSONL I/O
│       │   └── query.dart   # Query parser: #tag -tag prefix:period text
│       ├── screens/
│       │   ├── home.dart          # Adaptive nav (rail + FAB)
│       │   ├── list_screen.dart   # Entry list + FilterBar
│       │   ├── detail_screen.dart # View/edit entry, tag mgmt
│       │   ├── add_screen.dart    # Add with tag autocomplete
│       │   └── tags_screen.dart   # All tags browser
│       └── widgets/
│           ├── filter_bar.dart    # Query input + tag chips + suggestions
│           ├── entry_card.dart    # Card: headline + tag chips
│           └── tag_chips.dart     # Reusable tag chip
├── rust/             # flutter_rust_bridge FFI wrapper (depends on sift crate)
├── android/
└── linux/
```

## Data flow

```
            CLI                Flutter GUI
             │                     │
             ▼                     ▼
      cli/*.rs              services/api.dart
             │                     │
             ▼                     ▼
      store (JSONL) ◄─────── store (JSONL)
             │                     │
             ▼                     ▼
      index (mem)          in-memory list
             │                     │
             ▼                     ▼
      filter               query parser + filter
```

CLI and GUI share `~/.local/share/sift/entries.jsonl` — same data, same format.

## Query syntax

| Syntax | Meaning |
|--------|---------|
| `#tag` | exact tag match |
| `#prefix/*` | wildcard prefix |
| `-#tag` | exclude tag |
| `prefix:period` | date filter (done:this-week, due:overdue, created:today) |
| `text` | fulltext in headline/body/tags |

All clauses AND together. Periods: today, yesterday, tomorrow, this-week, last-week, next-week, this-month, last-month, overdue.

## Dev

```bash
# CLI
nix-shell --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store" shell.nix
cargo build && cargo test && cargo clippy -- -D warnings

# Flutter GUI
cd flutter && flutter build linux --debug
flutter run -d linux
```

## Dependencies

Rust: serde, serde_json, clap, clap_complete, chrono, uuid, toml, comfy-table, directories
Flutter: flutter_rust_bridge, path_provider
