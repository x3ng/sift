# sift — design philosophy

Why sift exists and how to think about it.

## Everything is a tag

No priority enum. No status field. No folders. No hidden metadata. Tags are the sole organization dimension.

Time is expressed via tags: `done/2026-05-24`, `due/2026-06-01`, `created/2026-05-23T10:00`. Config at `~/.config/sift/config.toml` defines which prefixes carry date semantics for filtering.

"done" is just a tag. The engine has no special-casing for any tag — filtering treats all tags equally. A done entry is simply an entry with a `done/...` tag.

## Tags as types

Tags are not just classification labels. **Tags are the type system.**

A tag declares what an entry *is*, not just how to find it. When the engine sees `#query`, it knows the entry's body is a combinator expression. When it sees `#png`, the body is an image path. The tag determines both how to filter the entry and how to interpret its body.

```
Entry { value: "...", tags: [#work, #urgent] }
                         ↑
            类型集合：同时属于 work 和 urgent 两个类型
```

This is **intersection typing** — an entry can belong to multiple types simultaneously, unlike Haskell's single-type assignment. Filtering is type-checking: `#work` asks "is this entry of type work?" and returns a boolean.

### Value is untyped

The entry's value (currently called Body in code) holds raw content. It carries no type information. All semantic meaning comes from tags.

This is a deliberate boundary: tags handle type semantics, the value handles storage. The two concerns do not overlap.

In the type-theoretic model: **Value is the untyped substrate, Tag is the type system layered on top.** The same value can have different types depending on its tags — this is ad hoc polymorphism, not dependent typing (the value does not determine the type; the user does).

### Tags determine value interpretation (design direction)

Tags are not passive labels. A tag determines how the engine interprets and operates on the value. This is the design direction — current implementation treats tags primarily as filter predicates, but the model supports richer interpretation:

| Tag | Value interpretation | Operations |
|---|---|---|
| `#query` | Combinator expression | Parse, execute, expand |
| `#png` | Image file path | Render as image |
| `#markdown` | Markdown text | Render rich text |
| `#due` | Date string | Compare, sort, range query |

The same raw content can have completely different semantics depending on its tags. This is tag-indexed interpretation: the tag set selects the interpretation function for the value.

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

All logical operations have explicit symbols. Space is a token separator, not an operator.

| Token | Role | Example | Meaning |
|-------|------|---------|---------|
| `#` | tag prefix | `#urgent` | include tag |
| `&` | AND | `#work & #urgent` | intersection |
| `,` | OR | `#work,#urgent` | union |
| `\|` | group OR | `#urgent \| #done` | alternative groups |
| `-` | exclude / bottom | `-#blocked`, `-*` | negation, bottom type |
| `/` | hierarchy | `work/rtd` | namespace / sub-type |
| `*` | wildcard | `work/*` | any sub-type |
| `$…$` | runtime primitive | `due/$today$` | impure: runtime → type |
| `>` | sort | `>due` `>created` | sort order |
| `@` | view | `@Work` | named view reference |
| `"` | quoting | `"fix login"` | literal text |

### Conflict prevention

- `#`, `-`, `&`, `$` are reserved — tag names cannot start with them. Validated at creation.
- `/` is the hierarchy separator — same in queries, storage, and display.
- `$…$` marks runtime primitives — the only impure syntax.

### Operator precedence

`&` (AND) binds tighter than `|` (group OR), which binds tighter than `,` (intra-clause OR). `-` (NOT) is unary prefix, highest precedence.

```
#work & #urgent | #life , #home
= (#work & #urgent) | (#life , #home)
```

## Operation layers

Each layer operates on the layer below.

| Layer | Operates on | Examples | Status |
|-------|------------|----------|--------|
| **L0: Atoms** | Tag strings | Normalize, validate reserved chars | done |
| **L1: Entry ops** | Individual entries | CRUD, filter, search, batch tag/delete | done |
| **L2: Tag-space ops** | The tag index | Global rename, merge tags, derived tags | partial |
| **UI** | Rendering | CLI, Flutter, third-party frontends | consumer |

### Named views (L2)

A named view is a saved combinator expression — "a tag expression given a name." Stored as regular entries with tag `view` and body = combinator expression. The `@view` syntax in the combinator language expands these at query time.

### Derived tags (L2, planned)

A derived tag is a type-level function — a tag defined by a rule rather than manually applied.

```toml
# config.toml
[derived_tags]
active = "-#done/*"
stale = "created/$this-week$ & -#done/*"
```

`#active` is not a tag you hand-apply. When the engine encounters it in a query, it expands to `-#done/*`. This is **type-level computation** (λω) — a type defined in terms of other types.

## Type-theoretic interpretation

sift's tag system can be understood through the lens of type theory. This was not deliberate — it emerged from the design.

### The model

```
Entry      = typed value     { id: Uuid, name: String, value: Value, tags: Set<Tag> }
Value      = untyped content  (raw string, no inherent type)
Tag        = type             (declares what the entry is)
⊥ (-*)     = bottom type      (entry with no tags, lattice minimum)
Filter     = type-checking    (Set<Tag> → Bool)
Combinator = type operator    (Set<Tag> → Set<Tag>)
```

`id` is the identity for deduplication and reference. `name` is human-readable. `value` is raw content. `tags` is the type set. All four are required.

An entry is a value with a set of types (tags). Filtering is type-checking: "does this entry have type `#work`?" returns a boolean. The combinator language operates at the type level.

### What sift has: λω (type operators)

Tags support type-level logical operations — types derived from other types:

```
-#done/*              -- type negation (exclusion)
#work & #urgent       -- type intersection
#work , #life         -- type union
-*                    -- bottom type (⊥): no tags at all
```

The `-` operator is the universal exclusion primitive. `-*` is the special case: excluding all tags yields the bottom of the type lattice — an entry with no type information.

These are genuine type operators: input types, output types. This is the foundation for derived tags:

```toml
# config.toml (planned)
[derived_tags]
active = "-#done/*"
stale = "created/$this-week$ & -#done/*"
```

A derived tag is a named type operator. `#active` expands to `-#done/*` at query time. Derived tag expressions use the same syntax as combinator queries — one parser, two uses.

### What sift has implicitly: row polymorphism

The filter function works uniformly across all tag types — the same code handles `#work`, `#markdown`, `#query` without type-specific branches. This is not System F's parametric polymorphism (`∀α. α → α`), where types are first-class values. It is closer to **row polymorphism**: operations that work on any record/tag set, based on the presence of specific labels.

`sift list #work` and `sift list #markdown` invoke the same filter logic. The tag is a label, not a type variable.

### Beyond the Lambda Cube: intersection types

The Lambda Cube does not include intersection types. But sift naturally needs them — an entry can belong to multiple types simultaneously (`[#work, #urgent]`).

Formal extensions exist:

```
Lambda Cube (λC)                         → three axes, no intersection
BCD-calculus (Barendregt, Coppo, Dezani) → λC + intersection types
System F∩                                → System F + intersection types
```

These are studied, formalized systems — not ad hoc additions. Intersection types have proper typing rules (`τ₁ ∧ τ₂` introduction and elimination).

sift is not strictly within the Lambda Cube. It includes intersection types, which are outside the Cube but have formal type-theoretic foundations. The Cube is a starting point, not a boundary.

### What sift does NOT have: λΠ (dependent types)

A type that depends on a value:

```
-- NOT implemented, just illustrating
entry.value.length > 100 → auto-tag #long
entry.value contains date → auto-tag #has-date
```

The type (tag) would be determined by the value (body content). sift does not do this — tags are manually applied, not derived from values.

**Common misconceptions:**

- `due/$today$` is NOT λΠ — it's runtime expansion. `$today$` is replaced by the string `2026-05-25`, producing a concrete tag. No type depends on a value.
- `work/*` is NOT λ2 — it's pattern matching on types, not parametric polymorphism. `*` is a wildcard, not a type variable.

### Tag conflict semantics

When an entry has multiple interpretation tags (`#query` and `#markdown`), the engine needs a resolution rule. Current design: first-match or explicit priority. This is an open question — tag-indexed interpretation requires a deterministic dispatch mechanism.

### Path to λC

Adding λΠ would mean: tag inference rules that derive tags from value content.

```toml
# config.toml (planned)
[tag_inference]
has-date = "value matches /\\d{4}-\\d{2}-\\d{2}/"
json = "value parses as JSON"
link = "value matches https?://"
```

This is a terminating operation: inspect value, produce tag set, always halts. Combined with the existing row polymorphism (λ2-like) and type operators (λω), this completes λC — a total functional language, not Turing complete.

### Completeness and the Turing boundary

Lambda Cube completeness (adding λΠ) would mean: body values automatically determine tags. This is implementable and does not make sift a general-purpose language.

The key distinction:

```
Lambda Cube 完备 (λC)    = 类型系统完备，所有程序停机（强规范化）
+ Y 组合子（不动点）       = 图灵完备，可以表达任意计算
```

A Lambda Cube complete sift without a Y combinator is a **total functional language** — all computations terminate, no recursion, no infinite loops. It is a strict subset of Lisp, not Lisp itself. Systems like Agda and Coq have λC as their core; they are not general-purpose languages.

The real "becomes Lisp" boundary is the Y combinator (general recursion), not Lambda Cube completeness.

**Current position:** sift has row polymorphism (λ2-like, implicit) and λω (type operators). Adding λΠ (tag inference from values) is a natural extension that keeps the system total — expressive enough to derive tags from values, but not powerful enough for arbitrary computation.

The combinator system is a **type-level computation language** for a tag index. Its ceiling is a design choice: total, terminating, useful.

## Pure core / Impure layer

The system separates pure type-theoretic computation from impure runtime operations. This follows the Haskell distinction between pure functions and `IO`.

### Pure core (type system, all functions total)

- Entry model: `{ id, name, value, tags }`
- Type lattice: `#tag`, `-*` (bottom), `&` (meet), `,` (join), `-` (complement)
- Filtering: `Set<Tag> → Bool` (type-checking)
- Derived tags: `Tag → Tag expression` (type operators)
- Combinator parser: `String → ParsedQuery` (pure function)

The core has no concept of time, no file I/O, no external state. Given the same inputs, it always produces the same outputs.

### Impure layer (runtime, IO-dependent)

- Date expansion: `due/$today$` → `due/2026-05-25` (depends on current time)
- JSONL storage: read/write entries to disk (file I/O)
- Tag inference: inspect value content to derive tags (may depend on external state)
- FFI bridge: pass JSON between Rust and Dart

The impure layer is thin — it wraps the core with IO, but all type-theoretic logic lives in the pure core.

### Why this matters

The pure core can be implemented in Haskell (or any pure functional language) without IO monads. The impure layer is a thin shell — the interesting design and type-theoretic content is all in the core.

## Minimalism

- One storage file: JSONL. No database.
- Four fields per entry: id, name, value, tags.
- Tags are the type system. The value is untyped raw content.
- User-facing primitives are few and composable.
- No configuration until it's genuinely needed.
- Features are engine concepts first, UI affordances second.
- Constraints are intentional. Expressiveness has a ceiling by design.

## Core architecture

```
src/
├── entry.rs          # Data model: Entry { id, name, value, tags }
├── config.rs         # XDG, TOML, date_prefixes, derived_tags
├── engine/           # ── Pure core (no IO, all functions total) ──
│   ├── types.rs      # Shared: DateOp enum, date parsing utils
│   ├── index.rs      # In-memory tag→ids mapping
│   ├── filter.rs     # Type-checking: Set<Tag> → Bool
│   └── combinator.rs # Query parser: String → ParsedQuery
├── io/               # ── Impure layer (IO-dependent) ──
│   └── store.rs      # JSONL read/write
├── api.rs            # SiftCore — wires pure core + impure layer
├── main.rs           # CLI binary entry point
└── cli/              # CLI commands (consume api.rs)
```

- `engine/` — pure core, no IO, testable in-memory
- `io/` — impure layer, file I/O, testable with temp files
- `api.rs` — thin facade, coordinates pure and impure

## Appendix: Type expression syntax

The surface syntax for the type system. Each primitive is a type operation.

### Grammar

```
expression := group ('|' group)*
group      := clause ('&' clause)*
clause     := include | or | exclude | runtime | view | fulltext | sort

include    := '#' tag-name
or         := '#' tag-name (',' tag-name)+
exclude    := '-#' tag-name | '-*'
runtime    := tag-name '$' primitive '$'    # impure: runtime-evaluated
view       := '@' view-name
fulltext   := '"' text '"' | bare-word
sort       := '>due' | '>created'

primitive  := 'today' | 'yesterday' | 'tomorrow'
            | 'this-week' | 'last-week' | 'next-week'
            | 'this-month' | 'last-month' | 'overdue'

tag-name   := [a-zA-Z0-9][a-zA-Z0-9._-]* ('/' [a-zA-Z0-9][a-zA-Z0-9._-]*)*
```

### Primitives

| Token | Type operation | Example | Meaning |
|-------|---------------|---------|---------|
| `#` | type check | `#urgent` | "has type urgent?" |
| `&` | type intersection | `#work & #urgent` | has both types |
| `,` | type union | `#work,#urgent` | has either type |
| `\|` | group union | `#urgent \| #done` | union of type expressions |
| `-` | type complement | `-#blocked`, `-*` | negation, bottom type |
| `/` | hierarchy | `work/urgent` | namespace / sub-type |
| `*` | wildcard | `work/*` | any sub-type |
| `$…$` | runtime primitive | `due/$today$` | impure: runtime → type |
| `@` | named expression | `@Work` | expand type expression |
| `>` | sort directive | `>due` | result ordering |
| `"` | quoting | `"fix login"` | literal text |

### Semantics

`/` separates hierarchy levels. `&` ANDs. `,` ORs. `-` excludes. Space is a separator. `$…$` marks runtime-evaluated primitives.

```
#urgent & #work         → has both urgent AND work types
#urgent,bug             → has urgent OR bug type
work/* -#blocked        → any work sub-type, not blocked
-*                      → bottom type (no tags at all)
due/$today$             → due namespace, today expanded at runtime
done/$this-week$        → done namespace, this-week expanded at runtime
work/urgent             → literal tag (no expansion)
```

`$…$` is impure — it depends on the current time. All other operations are pure.

Operator precedence: `&` > `|` > `,`. `-` is unary prefix.

### Wildcard patterns (glob)

`*` matches zero or more characters within a single level. `**` matches across hierarchy levels.

```
work/*            → work 下一级的所有子标签
*/done            → 以 done 结尾的标签
*due*             → 包含 due 的标签
work/**/urgent    → work 下任意深度的 urgent
```

This is the minimal complete set for hierarchical tag matching.

### Design constraints

- `#`, `-`, `&`, `$` are reserved — tag names cannot start with them
- `/` is the hierarchy separator — same in queries, storage, and display
- `*` is a glob wildcard (zero or more chars), `**` is cross-level
- `$…$` marks runtime primitives — the only impure syntax
