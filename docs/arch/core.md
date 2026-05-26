# Core architecture (Rust)

The core is the definitive engine. All type-theoretic logic lives here.

## Pure core / Impure layer

See [PHILOSOPHY.md](../PHILOSOPHY.md) for the design rationale.

```
src/engine/           # ── Pure core (no IO) ──
├── types.rs          # Shared: DateOp enum, date parsing utils
├── index.rs          # In-memory: tag→ids, times, counts
├── filter.rs         # Type-checking: tag ops, date filters
└── combinator.rs     # Type expression parser: String → ParsedQuery

src/io/               # ── Impure layer (IO) ──
└── store.rs          # JSONL read/write/append, file import/delete

src/api.rs            # SiftCore: wires pure core + impure layer
src/entry.rs          # Entry { id, name, body, tags }
src/config.rs         # XDG, TOML, date_prefixes
```

## Data model

```rust
struct Entry {
    id: Uuid,
    name: String,
    body: Body,       // target: simplify to Value (untyped raw content)
    tags: Vec<String>,
}

enum Body {
    Text { content: String },
    File { path: String },
    Empty,
}
```

## SiftCore (api.rs)

Thin facade. Coordinates pure core and impure layer. No business logic.

```rust
pub struct SiftCore {
    pub store: Store,    // impure: JSONL IO
    pub index: Index,    // pure: in-memory tag index
    pub cfg: Config,     // config
}
```

Key methods: `add`, `list`, `list_parsed`, `edit`, `delete`, `tag`, `rename_tag`, `batch_delete`, `batch_tag`, `export_to`, `import_from`, `all_tags`, `search`, `stats`.

## Engine modules

### types.rs — Shared types

`DateOp` enum (Today, Yesterday, ThisWeek, etc.) and `parse_date_value` / `parse_tag_date` utilities. Used by both filter.rs and combinator.rs.

### index.rs — In-memory index

```rust
pub struct Index {
    pub tag_index: HashMap<String, HashSet<Uuid>>,
    pub created_times: HashMap<Uuid, NaiveDateTime>,
    pub due_times: HashMap<Uuid, NaiveDateTime>,
    pub tag_counts: HashMap<String, usize>,
    pub entries: HashMap<Uuid, Entry>,
}
```

Rebuilt from entries on load. Updated incrementally on add/edit/delete.

### filter.rs — Type-checking engine

`FilterOptions::apply()` — the core type-checking function. Takes filter criteria, returns matching entry IDs.

Supports: tag intersection (`&`), union (`,`), exclusion (`-`), date filters, wildcard expansion, done filtering.

### combinator.rs — Type expression parser

`parse_query()` — parses a type expression string into `ParsedQuery`.

Tokenizer → classifier → view resolver → structured query.

## Storage

Single JSONL file at `~/.local/share/sift/entries.jsonl`.
Atomic writes via temp file + rename.
Managed files in `~/.local/share/sift/files/`.

## Dependencies

serde, serde_json, clap, clap_complete, chrono, uuid, toml, comfy-table, directories
