# sift — combinator system

The combinator system is sift's query language. Primitives compose into expressions — similar to Vim (operators + motions = commands) or lambda calculus (atoms compose to form programs).

## Grammar

```
expression := group ('|' group)*            # `|` = union of groups

group      := clause*

clause     := include | or | exclude | date | view | fulltext | sort

include    := '#' tag-name  ['/*']         # must match ALL
or         := '#' tag-name (',' tag-name)+ # must match ANY
exclude    := '-#' tag-name ['/*']         # must NOT match
date       := prefix ':' period            # tag prefix has date in period
             | '*:' period                 # any prefix has date in period
view       := '@' view-name               # expand named view
fulltext   := '"' text '"' | bare-word    # search name/body/tags
sort       := '>due' | '>created'         # sort results

period     := 'today' | 'yesterday' | 'tomorrow'
            | 'this-week' | 'last-week' | 'next-week'
            | 'this-month' | 'last-month'
            | 'overdue'
            | period (',' period)*         # OR within dates

tag-name   := [a-zA-Z0-9][a-zA-Z0-9._-]* ('/' [a-zA-Z0-9][a-zA-Z0-9._-]*)*
```

## Primitives

| Token | Name | Role | Example |
|-------|------|------|---------|
| `#` | include | entry MUST have this tag | `#urgent` |
| `,` | clause OR | any of the comma-joined values | `#urgent,bug` |
| `\|` | group OR | union of separate filter groups | `#urgent \| done:today` |
| `-` | exclude | entry must NOT have this tag | `-#blocked` |
| `*` | wildcard | match any sub-tag (prefix) | `#work/*` |
| `:` | date resolver | filter by date period | `done:this-week` |
| `*:` | wildcard date | any prefix matches the period | `*:today` |
| `@` | view | expand a named view | `@Work` |
| `>` | sort | sort by field | `>due`, `>created` |
| `"` | quoting | literal text (spaces, special chars) | `"fix login"` |

## Semantics

All clauses **AND** together. Commas **OR** within a single clause.

```
#urgent #work           → must have BOTH urgent AND work
#urgent,bug             → must have urgent OR bug
#urgent #work,life      → must have urgent AND (work OR life)
done:this-week,today    → done this week OR done today
#work/* -#blocked       → any work sub-tag, not blocked
#urgent | done:today    → has #urgent OR was done today
#work >due              → work entries, sorted by due date
```

The wildcard `#work/*` matches `work/rtd`, `work/design`, etc.  
Without `*`, `#work` matches only the exact tag `work`.

## Date prefix wildcard (`*:`)

`*:today` matches entries where **any** date-prefixed tag falls on today.  
`*:this-week` matches any date-prefixed tag in the current week.

Without `*`, you must specify the prefix: `done:today`, `created:this-week`.

Date prefixes are defined in `~/.config/sift/config.toml` (`tags.date_prefixes`).  
By default: `created`, `done`, `due`.

## Named views (`@`)

A view is a combinator expression saved with a name. Stored as entries with `view` tag.

```
sift add "Work" --tag view --body "#work/* -#done/*"
sift add "Urgent" --tag view --body "#urgent -#done/*"
```

Then query with `@Work` — the engine inlines the view's expression before filtering.

## Fulltext search

Bare words outside any clause become fulltext queries against `name`, `body`, and `tags`.

```
sift search     → CLI fulltext search
fix login       → matches name/body/tags containing "fix" and "login"
"fix login bug" → quoted: exact phrase match (tokenized as one term)
```

## Operator precedence

There is no precedence — all clauses are AND. The comma OR is the only intra-clause operator.

## Resolution order

1. Tokenize (split by whitespace, respecting quotes)
2. Classify each token (include, or, exclude, date, view, fulltext)
3. Resolve `@view` references (inlines the view's body expression)
4. Build filter: tags AND → tags OR → tags NOT → date filters → fulltext
5. Apply to entry index, return matches

## Design constraints

- `#` and `-` are **reserved** — tag names cannot start with them
- `:` is an operator **only** when RHS is a recognized period word; otherwise literal
- `/` is always user content, never an operator
- `*` is a wildcard, not a regex — prefix match only

## Comparison with SQL

The combinator is not a general-purpose query language. It's a domain-specific DSL optimized for tag-based retrieval:

```
sift combinator                  SQL equivalent
─────────────────────────────────────────────────
#urgent                         WHERE tag = 'urgent'
#work/*                         WHERE tag LIKE 'work/%'
#a,b                            WHERE tag IN ('a', 'b')
-#blocked                       WHERE id NOT IN (SELECT ...)
done:this-week                  WHERE tag = 'done/<date>' AND <date> IN range
@Work                           subquery / CTE expansion
```

Neither is a replacement for the other. SQL is general; combinator is fast to type and easy for both humans and LLMs to generate.

## Future primitives

| Primitive | Idea | Status |
|-----------|------|--------|
| `~` | fuzzy / semantic: `~like this` | deferred |
| `()` | grouping: `(#urgent \| #bug) -#done` | planned |
| `<>` | comparison: `due:<2026-06-01` | planned |
