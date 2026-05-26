# sift — architecture

Engine first, UI second. The Rust core is the definitive implementation. CLI and Flutter are pure consumers.

```
  ┌─────────────────────────────────┐
  │  SiftCore (src/)                │
  │  - Pure core (engine/)          │
  │  - Impure layer (io/)           │  ← definitive engine
  └────────────┬────────────────────┘
               │ API (FFI / CLI)
     ┌─────────┴─────────┐
     ▼                   ▼
  CLI (clap)        Flutter GUI
  (src/main.rs)     (flutter/)
```

- **[Core](arch/core.md)** — Rust engine: pure core (type system, filtering, parser) + impure layer (JSONL storage)
- **[CLI](arch/cli.md)** — 13 commands, delegates all logic to SiftCore
- **[Flutter](arch/flutter.md)** — Responsive GUI, communicates via dart:ffi JSON bridge

## Data model

```rust
Entry { id: Uuid, name: String, body: Body, tags: Vec<String> }
```

See [PHILOSOPHY.md](PHILOSOPHY.md) for the type-theoretic design (tags as types, Body → Value).

## Data flow

```
  CLI / Flutter GUI
         │
         ▼
    SiftCore (api.rs)
         │
   ┌─────┴──────────────┐
   ▼                    ▼
 Pure core           Impure layer
 engine/             io/
 ├─ filter           ├─ store (JSONL)
 ├─ combinator       └─ date expansion
 └─ index
```

## Dev

```bash
make build              # Rust core
make test               # Rust tests (28 tests)
make check              # build + test
make gui                # Flutter debug build
make gui-run            # Build + launch Flutter
make gui MODE=release   # Release build
make install            # Install CLI to ~/.cargo/bin
make clean              # Clean all artifacts
```
