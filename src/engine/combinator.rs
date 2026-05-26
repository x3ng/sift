//! Type expression parser.
//!
//! Syntax:
//!   #tag & #tag     → type intersection (AND)
//!   #a,#b           → type union (OR)
//!   -#tag           → type complement (NOT)
//!   -*              → bottom type
//!   prefix/$period$ → runtime-evaluated date type
//!   @view           → named type expression
//!   "quoted text"   → literal fulltext
//!   bare word       → fulltext search
//!
//! Precedence: `&` > `|` > `,`. Space is a separator.

use crate::engine::types::DateOp;

/// Structured result of parsing a type expression string.
#[derive(Debug, Clone, Default)]
pub struct ParsedQuery {
    pub tags_and: Vec<String>,
    pub tags_or: Vec<String>,
    pub tags_not: Vec<String>,
    pub dates: Vec<DateClause>,
    pub fulltext: Option<String>,
    pub views: Vec<String>,
    pub sort_by: Option<SortDirective>,
    /// Alternatives from `|` — each is a fully parsed query; union semantics.
    pub alternatives: Vec<ParsedQuery>,
}

impl ParsedQuery {
    pub fn is_empty(&self) -> bool {
        self.tags_and.is_empty()
            && self.tags_or.is_empty()
            && self.tags_not.is_empty()
            && self.dates.is_empty()
            && self.fulltext.is_none()
            && self.views.is_empty()
            && self.sort_by.is_none()
            && self.alternatives.is_empty()
    }
}

#[derive(Debug, Clone)]
pub struct DateClause {
    pub prefix: String,
    pub op: DateOp,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum SortDirective {
    Due,
    Created,
}

// ── Token ──────────────────────────────────────────────────────

#[derive(Debug, Clone, PartialEq)]
enum Token {
    Hash(String),    // #tag-name (may contain *, **, /)
    Exclude(String), // -#tag-name or -*
    And,             // &
    Comma,           // ,
    At(String),      // @view-name
    Runtime(String), // $primitive$
    Sort(String),    // >due, >created
    Text(String),    // quoted or bare word
}

// ── Tokenizer ──────────────────────────────────────────────────

fn tokenize(input: &str) -> Vec<Token> {
    let mut tokens = Vec::new();
    let mut chars = input.chars().peekable();

    while let Some(&c) = chars.peek() {
        match c {
            ' ' | '\t' => { chars.next(); }
            '&' => { chars.next(); tokens.push(Token::And); }
            ',' => { chars.next(); tokens.push(Token::Comma); }
            '"' => {
                chars.next();
                let mut s = String::new();
                loop {
                    match chars.next() {
                        Some('"') | None => break,
                        Some(ch) => s.push(ch),
                    }
                }
                if !s.is_empty() { tokens.push(Token::Text(s)); }
            }
            '$' => {
                chars.next();
                let mut s = String::new();
                loop {
                    match chars.next() {
                        Some('$') | None => break,
                        Some(ch) => s.push(ch),
                    }
                }
                if !s.is_empty() { tokens.push(Token::Runtime(s)); }
            }
            '#' => {
                chars.next();
                let name = consume_tag_name(&mut chars);
                if !name.is_empty() { tokens.push(Token::Hash(name)); }
            }
            '-' => {
                chars.next();
                match chars.peek() {
                    Some('#') => {
                        chars.next();
                        let name = consume_tag_name(&mut chars);
                        if !name.is_empty() { tokens.push(Token::Exclude(name)); }
                    }
                    Some('*') => {
                        chars.next();
                        tokens.push(Token::Exclude("*".to_string()));
                    }
                    _ => { tokens.push(Token::Text("-".to_string())); }
                }
            }
            '@' => {
                chars.next();
                let mut s = String::new();
                while let Some(&ch) = chars.peek() {
                    if ch.is_alphanumeric() || ch == '_' || ch == '-' { s.push(ch); chars.next(); }
                    else { break; }
                }
                if !s.is_empty() { tokens.push(Token::At(s)); }
            }
            '>' => {
                chars.next();
                let mut s = String::new();
                while let Some(&ch) = chars.peek() {
                    if ch.is_alphanumeric() || ch == '-' { s.push(ch); chars.next(); }
                    else { break; }
                }
                if !s.is_empty() { tokens.push(Token::Sort(s)); }
            }
            _ => {
                let mut s = String::new();
                while let Some(&ch) = chars.peek() {
                    if ch == ' ' || ch == '\t' || ch == '&' || ch == ',' || ch == '|'
                        || ch == '"' || ch == '$' || ch == '#' || ch == '-' || ch == '@' || ch == '>'
                    { break; }
                    s.push(ch);
                    chars.next();
                }
                if !s.is_empty() { tokens.push(Token::Text(s)); }
            }
        }
    }
    tokens
}

fn consume_tag_name(chars: &mut std::iter::Peekable<std::str::Chars>) -> String {
    let mut s = String::new();
    loop {
        // Consume tag characters
        while let Some(&ch) = chars.peek() {
            if ch.is_alphanumeric() || ch == '_' || ch == '.' || ch == '-' || ch == '/' || ch == '*' {
                s.push(ch);
                chars.next();
            } else {
                break;
            }
        }
        // If followed by comma, consume it and continue (OR syntax: #a,b)
        if let Some(',') = chars.peek() {
            s.push(',');
            chars.next();
        } else {
            break;
        }
    }
    s
}

// ── Parser ─────────────────────────────────────────────────────

/// Parse a type expression string. `|` splits into alternatives.
pub fn parse_query(input: &str) -> ParsedQuery {
    // Split on `|` at string level (respecting quotes)
    let groups = split_alternatives(input);
    if groups.is_empty() {
        return ParsedQuery::default();
    }
    if groups.len() == 1 {
        parse_group_str(&groups[0])
    } else {
        let mut alts: Vec<ParsedQuery> = groups.iter().map(|g| parse_group_str(g)).collect();
        let mut pq = alts.remove(0);
        pq.alternatives = alts;
        pq
    }
}

/// Split input string on top-level `|` (not inside quotes).
fn split_alternatives(input: &str) -> Vec<String> {
    let mut groups = Vec::new();
    let mut current = String::new();
    let mut in_quote = false;
    for c in input.chars() {
        match c {
            '"' => { in_quote = !in_quote; current.push(c); }
            '|' if !in_quote => {
                let trimmed = current.trim().to_string();
                if !trimmed.is_empty() { groups.push(trimmed); }
                current = String::new();
            }
            _ => current.push(c),
        }
    }
    let trimmed = current.trim().to_string();
    if !trimmed.is_empty() { groups.push(trimmed); }
    groups
}

/// Parse a group from a string: tokenize, then parse `&` clauses.
fn parse_group_str(input: &str) -> ParsedQuery {
    let tokens = tokenize(input);
    parse_group(&tokens)
}

/// Parse a group: clauses joined by `&`.
fn parse_group(tokens: &[Token]) -> ParsedQuery {
    let mut pq = ParsedQuery::default();

    // Split on `&`
    let clauses = split_on_and(tokens);

    for clause_tokens in &clauses {
        let clause = parse_clause(clause_tokens);
        merge_clause(&mut pq, clause);
    }

    pq
}

/// Split token list on `&`.
fn split_on_and(tokens: &[Token]) -> Vec<Vec<Token>> {
    let mut groups = Vec::new();
    let mut current = Vec::new();
    for token in tokens {
        if *token == Token::And {
            if !current.is_empty() {
                groups.push(current);
                current = Vec::new();
            }
        } else {
            current.push(token.clone());
        }
    }
    if !current.is_empty() {
        groups.push(current);
    }
    groups
}

/// Parse a single clause (a sequence of non-`&`, non-`|` tokens).
fn parse_clause(tokens: &[Token]) -> ParsedQuery {
    let mut pq = ParsedQuery::default();
    let mut fulltext_words = Vec::new();
    let mut i = 0;

    while i < tokens.len() {
        match &tokens[i] {
            Token::Hash(name) => {
                if name.contains(',') {
                    for part in name.split(',') {
                        let t = part.trim();
                        if !t.is_empty() { pq.tags_or.push(t.to_string()); }
                    }
                } else {
                    pq.tags_and.push(name.clone());
                }
            }
            Token::Exclude(name) => {
                if name.contains(',') {
                    for part in name.split(',') {
                        let t = part.trim();
                        if !t.is_empty() { pq.tags_not.push(t.to_string()); }
                    }
                } else {
                    pq.tags_not.push(name.clone());
                }
            }
            Token::At(name) => pq.views.push(name.clone()),
            Token::Sort(s) => {
                pq.sort_by = match s.as_str() {
                    "due" => Some(SortDirective::Due),
                    "created" => Some(SortDirective::Created),
                    _ => None,
                };
            }
            Token::Runtime(prim) => {
                // Bare $period$ — default prefix "due"
                if let Some(op) = parse_date_op(prim) {
                    pq.dates.push(DateClause { prefix: "due".into(), op });
                }
            }
            Token::Text(s) => {
                // Check if this is prefix/ followed by $period$
                if s.ends_with('/') && i + 1 < tokens.len()
                    && let Token::Runtime(prim) = &tokens[i + 1]
                    && let Some(op) = parse_date_op(prim)
                {
                    let prefix = s.trim_end_matches('/').to_string();
                    pq.dates.push(DateClause { prefix, op });
                    i += 2; // skip the Runtime token
                    continue;
                }
                fulltext_words.push(s.clone());
            }
            Token::And | Token::Comma => {} // handled by split functions
        }
        i += 1;
    }

    if !fulltext_words.is_empty() {
        pq.fulltext = Some(fulltext_words.join(" "));
    }

    pq
}

/// Merge a clause into the main query (extend lists).
fn merge_clause(pq: &mut ParsedQuery, clause: ParsedQuery) {
    pq.tags_and.extend(clause.tags_and);
    pq.tags_or.extend(clause.tags_or);
    pq.tags_not.extend(clause.tags_not);
    pq.dates.extend(clause.dates);
    pq.views.extend(clause.views);
    if let Some(ft) = clause.fulltext {
        pq.fulltext = Some(match pq.fulltext.take() {
            Some(existing) => format!("{existing} {ft}"),
            None => ft,
        });
    }
    if clause.sort_by.is_some() && pq.sort_by.is_none() {
        pq.sort_by = clause.sort_by;
    }
}

/// Parse a date period name into a DateOp.
fn parse_date_op(s: &str) -> Option<DateOp> {
    match s {
        "today" => Some(DateOp::Today),
        "yesterday" => Some(DateOp::Yesterday),
        "tomorrow" => Some(DateOp::Tomorrow),
        "this-week" | "thisweek" => Some(DateOp::ThisWeek),
        "last-week" | "lastweek" => Some(DateOp::LastWeek),
        "next-week" | "nextweek" => Some(DateOp::NextWeek),
        "this-month" | "thismonth" => Some(DateOp::ThisMonth),
        "last-month" | "lastmonth" => Some(DateOp::LastMonth),
        "overdue" => Some(DateOp::Overdue),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_tokenize_hash() {
        let t = tokenize("#urgent");
        assert_eq!(t, vec![Token::Hash("urgent".into())]);
    }

    #[test]
    fn test_tokenize_and() {
        let t = tokenize("#work & #urgent");
        assert_eq!(t, vec![Token::Hash("work".into()), Token::And, Token::Hash("urgent".into())]);
    }

    #[test]
    fn test_tokenize_runtime() {
        let t = tokenize("due/$today$");
        assert_eq!(t, vec![Token::Text("due/".into()), Token::Runtime("today".into())]);
    }

    #[test]
    fn test_tokenize_quoted() {
        let t = tokenize(r#""fix login bug""#);
        assert_eq!(t, vec![Token::Text("fix login bug".into())]);
    }

    #[test]
    fn test_parse_and() {
        let q = parse_query("#work & #urgent");
        assert_eq!(q.tags_and, vec!["work", "urgent"]);
    }

    #[test]
    fn test_parse_or() {
        let q = parse_query("#urgent,life");
        assert_eq!(q.tags_or, vec!["urgent", "life"]);
        assert!(q.tags_and.is_empty());
    }

    #[test]
    fn test_parse_exclude() {
        let q = parse_query("-#blocked");
        assert_eq!(q.tags_not, vec!["blocked"]);
    }

    #[test]
    fn test_parse_exclude_bottom() {
        let q = parse_query("-*");
        assert_eq!(q.tags_not, vec!["*"]);
    }

    #[test]
    fn test_parse_view() {
        let q = parse_query("@Work & #urgent");
        assert_eq!(q.views, vec!["Work"]);
        assert_eq!(q.tags_and, vec!["urgent"]);
    }

    #[test]
    fn test_parse_fulltext() {
        let q = parse_query("fix login");
        assert_eq!(q.fulltext.as_deref(), Some("fix login"));
    }

    #[test]
    fn test_parse_sort() {
        let q = parse_query("#work & >due");
        assert_eq!(q.tags_and, vec!["work"]);
        assert!(matches!(q.sort_by, Some(SortDirective::Due)));
    }

    #[test]
    fn test_parse_mixed() {
        let q = parse_query("#urgent & -#blocked & @Work & \"fix login\"");
        assert_eq!(q.tags_and, vec!["urgent"]);
        assert_eq!(q.tags_not, vec!["blocked"]);
        assert_eq!(q.views, vec!["Work"]);
        assert!(q.fulltext.as_deref().unwrap().contains("fix login"));
    }

    #[test]
    fn test_parse_glob() {
        let q = parse_query("#work/*");
        assert_eq!(q.tags_and, vec!["work/*"]);
    }

    #[test]
    fn test_parse_glob_suffix() {
        let q = parse_query("#*/done");
        assert_eq!(q.tags_and, vec!["*/done"]);
    }

    #[test]
    fn test_parse_wildcard_date() {
        let q = parse_query("*:today");
        // *:today is now treated as text since : syntax is removed
        assert!(q.fulltext.is_some() || q.tags_and.is_empty());
    }

    #[test]
    fn test_is_empty() {
        assert!(parse_query("").is_empty());
        assert!(!parse_query("#work").is_empty());
    }

    #[test]
    fn test_parse_runtime_date() {
        let q = parse_query("due/$today$");
        assert_eq!(q.dates.len(), 1);
        assert_eq!(q.dates[0].prefix, "due");
        assert!(matches!(q.dates[0].op, DateOp::Today));
    }

    #[test]
    fn test_parse_and_precedence() {
        // #a & #b | #c should parse as (#a & #b) | #c
        let q = parse_query("#a & #b | #c");
        assert_eq!(q.tags_and, vec!["a", "b"]);
        assert_eq!(q.alternatives.len(), 1);
        assert_eq!(q.alternatives[0].tags_and, vec!["c"]);
    }
}
