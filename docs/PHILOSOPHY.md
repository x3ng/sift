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

Flutter calls Rust via `dart:ffi` — a thin `NativeService` passes JSON over C FFI. No logic is duplicated in Dart.

## Combinator system

Inspired by Vim: operators + motions = commands. Tag combinators are primitives that compose into expressions.

### Primitives

| Token | Role | Search | Tag input |
|-------|------|--------|-----------|
| `#` | include AND | `#urgent` → filter | N/A |
| `,` | include OR | `#urgent,bug` → any | N/A |
| `\|` | group OR | `#urgent \| done:today` → union | N/A |
| `-` | exclude | `-#blocked` → omit | N/A |
| `/` | hierarchy | `#work/rtd` → subtree | `work/rtd` → nested tag |
| `:` | date resolver | `done:this-week` → period | `meeting:today` → `meeting/2026-05-24` |
| `*:` | wildcard date | `*:today` → any prefix's date | N/A |
| `*` | wildcard | `#work/*` → any sub-tag | N/A |
| `>` | sort | `>due` `>created` → order | N/A |
| `@` | view | `@Work` → named view | N/A |
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

Views are stored as regular entries with tag `view` and body = combinator expression. The GUI renders them as sidebar/drawer tabs.

## The lambda architecture

sift's combinators mirror lambda calculus: three levels of abstraction over the tag space.

| Calculus | sift | Syntax | Meaning |
|---|---|---|---|
| **λs** (body-level) | Fulltext search | `"keyword"` | Match text in headline/body/tags |
| **λp** (tag-level) | Predicate filtering | `#tag`, `-#tag`, `tag/*`, `tag:period` | Filter entries by tag membership |
| **λc** (combinator-level) | Named view | `@view` | Reference a named combinator expression |
| **Composition** | AND, OR | token chain, `#a,#b` | Combine expressions |
| **Application** | Filter execution | `(filter)(entries)` | Apply filter to entry set |

Future: **λm** (meta-level) — operations on views themselves: view intersection, union, difference, analytics. Deferred until needed.

## Combinator grammar (formal)

```
expression := clause+
clause     := include | exclude | view | date | fulltext
include    := '#' tag-name ['/*']
exclude    := '-#' tag-name ['/*']
view       := '@' view-name
date       := prefix ':' period
fulltext   := '"' text '"' | bare-word
tag-name   := [a-zA-Z0-9][a-zA-Z0-9._-]* ('/' [a-zA-Z0-9][a-zA-Z0-9._-]*)*
```

## Core architecture: IO / Engine separation

```
src/
├── entry.rs          # Data model: Entry struct
├── config.rs         # XDG, TOML, date_prefixes
├── io/
│   └── store.rs      # JSONL read/write — pure I/O, no logic
├── engine/
│   ├── index.rs      # In-memory tag→ids mapping
│   ├── filter.rs     # Filter ops on index
│   └── combinator.rs # Query tokenizer / parser / @view resolver
├── api.rs            # SiftCore — thin coordinator, wires io + engine
├── main.rs           # CLI binary entry point
└── cli/              # CLI commands (consume api.rs)
```

- `io/` — pure I/O, testable with temp files
- `engine/` — pure logic, testable in-memory
- `api.rs` — thin facade, no logic

## Minimalism

- One storage file: JSONL. No database.
- Four fields per entry: id, headline, body, tags.
- User-facing primitives are few and composable.
- No configuration until it's genuinely needed.
- Features are engine concepts first, UI affordances second.
