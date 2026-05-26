# CLI architecture

CLI is a frontend. All logic lives in [SiftCore](core.md).

## Structure

```
src/main.rs           # Binary entry: sift::cli::run()
src/cli/
├── mod.rs            # Clap subcommand definitions + dispatch
├── add.rs            # sift add --tag --at --body
├── list.rs           # sift list --tag --any --exclude --due --query --sort
├── tag_cmd.rs        # sift tag <id> --add --rm --at
├── edit.rs           # sift edit <id> --name --body
├── delete.rs         # sift delete <id>
├── show.rs           # sift show <id>
├── tags_cmd.rs       # sift tags --like
├── search_cmd.rs     # sift search <query>
├── stats.rs          # sift stats
├── export.rs         # sift export <path>
├── import.rs         # sift import <path> (JSONL + markdown)
└── batch.rs          # sift batch --add --rm --delete
```

## Pattern

Each subcommand module exposes `pub fn run(core: &SiftCore, ...) -> Result<_, _>`.
Parsing and formatting is local to each module. Business logic delegates to SiftCore.

## 13 commands

add, list, tag, edit, delete, show, tags, search, stats, batch, export, import, completion

## Output formats

`list` supports: table (comfy-table), json, jsonl.
`export` supports: jsonl, json, markdown.
