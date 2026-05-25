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

## Quick start

```bash
make check      # build + test Rust core
make gui        # build Flutter GUI
make gui-run    # build + launch Flutter GUI
make help       # show all targets
```

## CLI Reference

```
sift add <name> --tag <tags> --at <spec> --body <text>
sift list --tag|--any|--exclude --due <period> --query <combinator> --sort --format
sift tag <id> --add <tags> --rm <tags> --at <spec>
sift edit <id> --name|--body
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

### Combinator query (search bar & `--query`)

```
#urgent              exact tag match
#urgent,bug          any of these (OR)
#urgent | done:today  union of groups (OR)
#work/*              wildcard prefix
-#blocked            exclude tag
done:this-week       date filter
*:today              any prefix's date is today
>due                 sort by due date
@Work                named view
"fix login"          quoted fulltext
plain text           fulltext in name/body/tags
```

See [docs/COMBINATOR.md](docs/COMBINATOR.md) for the full grammar.

## Architecture

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## License

MIT
