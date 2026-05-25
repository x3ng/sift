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
  │  - JSONL + managed files        │
  └────────────┬────────────────────┘
               │ API (FFI / CLI)
     ┌─────────┴─────────┐
     ▼                   ▼
  CLI (clap)        Flutter GUI
  (src/main.rs)     (flutter/)
                         │
                    future third-party
                    frontends (web, TUI, etc.)
```

Flutter calls Rust via `dart:ffi` — a thin `NativeService` (~300 lines) passes JSON over C FFI. All combinator parsing, filtering, and storage logic lives in Rust.

## Data model

```rust
struct Entry {
    id: Uuid,
    name: String,
    body: Body,
    tags: Vec<String>,
}

enum Body {
    Text { content: String },   // inline text (plain or markdown)
    File { path: String },      // managed file, relative to data dir
    Empty,                      // pure todo / reminder
}
```

Time via tags: `created/2026-05-23T10:00`, `done/2026-05-23T12:00`, `due/2026-06-01`.
Config at `~/.config/sift/config.toml` defines which prefixes are date-typed.

Storage: JSONL at `~/.local/share/sift/entries.jsonl`. Managed files at `~/.local/share/sift/files/`.

## File map

```
src/
├── lib.rs            # pub mod re-exports
├── entry.rs          # Entry, Body enum, tag normalize
├── config.rs         # XDG, TOML, date_prefixes
├── io/
│   └── store.rs      # JSONL read/write/append, file import/delete
├── engine/
│   ├── index.rs      # In-memory: tag→ids, times, counts
│   ├── filter.rs     # Tag ops (and/or/not/*), date filters
│   └── combinator.rs # Query tokenizer/parser, @view resolver
├── api.rs            # SiftCore: unified API
├── main.rs           # Binary: sift::cli::run()
└── cli/
    ├── mod.rs         # Clap subcommands
    ├── add.rs         # sift add --tag --at --body
    ├── list.rs        # sift list --tag --any --exclude --due --query --sort
    ├── tag_cmd.rs     # sift tag <id> --add --rm --at
    ├── edit.rs        # sift edit <id> --name --body
    ├── delete.rs      # sift delete <id>
    ├── show.rs        # sift show <id>
    ├── tags_cmd.rs    # sift tags --like
    ├── search_cmd.rs  # sift search <query>
    ├── stats.rs       # sift stats
    ├── export.rs      # sift export <path>
    ├── import.rs      # sift import <path>
    └── batch.rs       # sift batch --add --rm --delete

flutter/              # Flutter cross-platform GUI
├── lib/
│   ├── main.dart
│   └── src/
│       ├── services/
│       │   ├── ffi_service.dart  # NativeService: thin FFI wrapper
│       │   └── prefs.dart       # GUI preferences (pinned filter)
│       ├── screens/
│       │   ├── home.dart          # Responsive layout (rail/drawer)
│       │   ├── list_screen.dart   # Entry list + FilterBar
│       │   ├── detail_screen.dart # View/edit entry, tag mgmt
│       │   ├── add_screen.dart    # Add with body type selector
│       │   └── tags_screen.dart   # All tags browser
│       └── widgets/
│           ├── filter_bar.dart    # Thin FilterBar → TagCombinator
│           ├── tag_combinator.dart # Search/tagging input widget
│           ├── entry_card.dart    # Custom entry card
│           └── tag_chips.dart     # Custom tag chip
├── rust/             # dart:ffi bridge crate (cdylib)
│   ├── Cargo.toml
│   └── src/
│       ├── lib.rs     # extern "C" FFI functions
│       └── api.rs     # DTOs + SiftCoreWrapper
└── linux/
```

## Data flow

```
         CLI                        Flutter GUI
          │                              │
          ▼                              ▼
   cli/*.rs                     NativeService
          │                        (dart:ffi)
          ▼                              │
   SiftCore ◄────────────────────────────┘
   (src/api.rs)
          │
    ┌─────┴─────┐
    ▼           ▼
  Store       Index
  (JSONL)     (memory)
```

CLI and GUI share the same `SiftCore` — same data, same logic, same file.

## Combinator system

See [COMBINATOR.md](COMBINATOR.md) for the full grammar and semantics.

## Dev

```bash
make build        # Rust core
make test         # Rust tests (27 tests)
make check        # build + test
make gui          # Flutter debug build
make gui-run      # Build + launch Flutter
make gui MODE=release  # Release build
make install      # Install sift CLI to ~/.cargo/bin
make clean        # Clean all artifacts
```

## Dependencies

Rust: serde, serde_json, clap, clap_complete, chrono, uuid, toml, comfy-table, directories
Flutter: ffi, path_provider, file_picker
