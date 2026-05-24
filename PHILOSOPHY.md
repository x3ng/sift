# sift — design philosophy

Why sift exists and how to think about it.

## Everything is a tag

No priority enum. No status field. No folders. No hidden metadata. Tags are the sole organization dimension.

Time is expressed via tags: `done/2026-05-24`, `due/2026-06-01`, `created/2026-05-23T10:00`. Config at `~/.config/sift/config.toml` defines which prefixes carry date semantics for filtering, but the `:` combinator works for any prefix.

"done" is just a tag. There is no special-casing — no `is_done()` in the engine, no "Done" tab in the UI. A done entry is simply an entry with a `done/...` tag.

## Engine first, UI second

sift is a **tag engine** with frontends, not a GUI app with a backend.

```
SiftCore (Rust)          ← definitive engine
  ├── CLI (clap)         ← one frontend
  ├── Flutter GUI         ← another frontend
  └── future: web, TUI, third-party
```

**Rule:** logic goes in the engine layer. Frontends only handle rendering and interaction. The combinator parser, date resolver, query engine — all in Rust. When a feature could live in either layer, it belongs in core.

Current Dart `SiftService` directly reads JSONL as a temporary measure before `flutter_rust_bridge` code generation is wired up. The Dart `query.dart` parser is a duplicate of what should be in Rust.

## Combinator system

Inspired by Vim: operators + motions = commands. Tag combinators are primitives that compose into expressions.

### Primitives

| Token | Role | Search | Tag input |
|-------|------|--------|-----------|
| `#` | include | `#urgent` → filter | N/A |
| `-` | exclude | `-#blocked` → omit | N/A |
| `/` | hierarchy | `#work/rtd` → subtree | `work/rtd` → nested tag |
| `:` | date resolver | `done:this-week` → period | `meeting:today` → `meeting/2026-05-24` |
| `*` | wildcard | `#work/*` → any sub-tag | N/A |
| `"` | quoting | `"fix login"` → literal | `"tag with spaces"` → literal |

### Conflict prevention

- `#` and `-` are reserved — tag names cannot start with them. Validated at creation.
- `:` is only an operator when the right side is a recognized date period. Otherwise literal.
- `/` is always user content — never an operator.

## Operation layers

Like lambda calculus: each layer operates on the layer below.

| Layer | Operates on | Examples | Status |
|-------|------------|----------|--------|
| **L0: Atoms** | Tag strings | Normalize, validate reserved chars | done |
| **L1: Entry ops** | Individual entries | CRUD, filter, search, batch tag/delete | active |
| **L2: Tag-space ops** | The tag index | Global rename, merge tags, named views | planned |
| **UI** | Rendering | CLI, Flutter, third-party frontends | consumer |

### Named views (L2, planned)

A named view is a saved combinator expression — "a tag expression given a name." This is an engine concept, not a UI feature. The core stores named queries; frontends render them however they see fit (tabs, bookmarks, CLI shortcuts).

```
"Work" = #work/* -#done/*
"Urgent" = #urgent -#done/*
```

Views persist in `~/.config/sift/views.json`. API: `save_view`, `list_views`, `get_view`, `delete_view`.

## Minimalism

- One storage file: JSONL. No database.
- Four fields per entry: id, headline, body, tags.
- User-facing primitives are few and composable.
- No configuration until it's genuinely needed.
- Features are engine concepts first, UI affordances second.
