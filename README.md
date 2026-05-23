# sift

Personal entry tag index tool. Everything is a tag — no priority enums, no status fields, no folders.

```
sift add "fix login bug" --tag urgent,bug,work/rtd --at created
sift list --tag work/rtd --exclude blocked
sift list --tag done/*
sift batch --tag someday --delete
sift export tasks.md --format md
```

## Concept

4 fields per entry. Tags are the sole organization dimension.

| field | who | what |
|---|---|---|
| headline | you | one line |
| body | you | free text (md, plain, anything) |
| tags | you | everything: priority, status, project, time |
| id | system | UUID |

Time is expressed via tags: `created/`, `done/`, `due/` with configurable date formats.
Config at `~/.config/sift/config.toml` defines which prefixes carry date semantics.

Storage: single JSONL file at `~/.local/share/sift/entries.jsonl`. No database.

## Install

### NixOS

```bash
nix-shell shell.nix
cargo build --release
```

### Other Linux / macOS

```bash
# need: rust, cargo
cargo build --release
```

### Flutter GUI (Linux + Android)

```bash
cd flutter
flutter build linux --debug
flutter run -d linux
```

## CLI Reference

```
sift add <headline> --tag <tags> --at <spec> --body <text>
sift list --tag|--any|--exclude --due <period> --sort --format
sift tag <id> --add <tags> --rm <tags> --at <spec>
sift edit <id> --headline|--body
sift delete <id>
sift show <id>
sift tags --like <pattern>
sift search <query>
sift stats
sift batch --tag|--exclude --add|--rm|--delete
sift export <path> --format jsonl|json|md
sift import <path> --merge
sift completion bash|zsh|fish
```

### Query syntax (GUI search bar)

```
#urgent         exact tag match
#work/*         wildcard prefix
-#blocked       exclude tag
done:this-week  date filter on any configured prefix
plain text      full-text in headline/body/tags
```

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md).

## License

MIT
