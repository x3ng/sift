# sift — architecture

Personal entry tag index tool. All organization dimensions are tags — no priority enum, no status field, no hierarchy.

## Development philosophy: engine first, UI second

sift is a **tag engine** with frontends, not a GUI app with a backend. The Rust `SiftCore` is the definitive implementation of the tag combinator system. CLI and GUI are pure consumers — they do not reimplement engine logic.

```
  ┌─────────────────────────────────┐
  │  SiftCore (src/)                │
  │  - Entry CRUD, index, filter    │
  │  - Combinator parser, resolver  │
  │  - Tag-space operations (L2)    │  ← definitive engine
  │  - JSONL store                  │
  └────────────┬────────────────────┘
               │ API (frb / FFI / CLI)
     ┌─────────┴─────────┐
     ▼                   ▼
  CLI (clap)        Flutter GUI
  (src/main.rs)     (flutter/)
                         │
                    future third-party
                    frontends (web, TUI, etc.)
```

**Rule:** If logic can be implemented in the engine layer, it goes there. UI/frontend layers only handle rendering and interaction. The combinator parser (query syntax, date shorthands, tokenizer) must live in Rust so all frontends share one implementation. Frontend-specific code should be thin — call engine API, display results.

**Transition note:** Currently the Flutter Dart `SiftService` directly reads JSONL because `flutter_rust_bridge` code generation is not yet wired up. The Dart `query.dart` parser is a temporary duplicate of what should be in Rust. When frb is integrated, Dart-side combinator logic moves to Rust and `SiftService` becomes a thin FFI wrapper.

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

## Combinator system

sift uses a composable tag combinator language — think Vim (operators + motions = commands). Primitives combine to form expressions. The same combinator engine powers both search and tag input.

### Primitives

| Token | Role | Search (filter) | Tag Input |
|-------|------|-----------------|-----------|
| `#` | include operator | `#urgent` → filter by tag | N/A |
| `-` | exclude operator | `-#blocked` → exclude | N/A |
| `/` | hierarchy separator | `#work/rtd` → match subtree | `work/rtd` → nested tag |
| `:` | date resolver | `done:this-week` → period filter | `done:today` → expands to `done/2026-05-24` |
| `*` | wildcard | `#work/*` → any sub-tag | N/A |
| `"` | quoting | `"fix login"` → literal fulltext | `"tag with spaces"` → literal tag |

### Operation layers

| Layer | Operates on | Operations | Status |
|-------|-------------|------------|--------|
| L0: Atoms | Tag strings | Normalize, validate reserved chars | done |
| L1: Entry ops | Individual entries | CRUD, filter, search, batch | active |
| L2: Tag-space ops | The tag index | Global rename, merge, named views, analytics | planned |

UI (CLI, Flutter, future third-party) is a pure consumer of the engine — anyone can build a frontend on top of `SiftCore`.

### Named views (L2)

A **named view** is a saved combinator expression — essentially "a tag expression given a name." This is an engine-level concept, not a UI feature. The core stores named queries; frontends render them as tabs, bookmarks, or CLI shortcuts as they see fit.

```
"Work" = #work/* -#done/*
"Urgent" = #urgent -#done/*
"Done" = #done/*
```

`SiftCore` provides: `save_view(name, tokens)`, `list_views()`, `get_view(name)`, `delete_view(name)`.
Views persist in `~/.config/sift/views.json` — separate from entry data, user-configurable.

### Conflict prevention

- `#` and `-` are reserved — tag names cannot start with them. Validation at creation time.
- `:` is only an operator when LHS matches `date_prefixes` in config.toml. Otherwise it's literal.
- `/` is always user content — no conflict.

### Query syntax

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
