//! Combinator query parser.
//!
//! Syntax:
//!   #tag           → include tag, must all match (AND)
//!   #a,#b          → include tags, any matches (OR) — comma = OR
//!   -#tag          → exclude tag
//!   prefix:period  → date filter on tag prefix
//!   @view          → expand named view
//!   "quoted text"  → literal fulltext
//!   bare word      → fulltext search
//!
//! Clauses AND together. Commas OR within a clause.

use crate::engine::types::DateOp;

/// Structured result of parsing a combinator query string.
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

/// Parse a combinator query string. `|` splits into alternatives (union semantics).
pub fn parse_query(input: &str) -> ParsedQuery {
    let groups = split_alternatives(input);
    if groups.is_empty() {
        return ParsedQuery::default();
    }
    if groups.len() == 1 {
        parse_single(&groups[0])
    } else {
        let mut alts: Vec<ParsedQuery> = groups.iter().map(|g| parse_single(g)).collect();
        // Pop the first as the primary, rest as alternatives
        let primary = alts.remove(0);
        let mut pq = primary;
        pq.alternatives = alts;
        pq
    }
}

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

fn parse_single(input: &str) -> ParsedQuery {
    let mut tags_and = Vec::new();
    let mut tags_or = Vec::new();
    let mut tags_not = Vec::new();
    let mut dates = Vec::new();
    let mut views = Vec::new();
    let mut fulltext_words = Vec::new();
    let mut sort_by = None;

    let tokens = tokenize(input);

    for token in &tokens {
        if let Some(dir) = parse_sort(token) {
            sort_by = Some(dir);
        } else if token.starts_with("@") && token.len() > 1 {
            views.push(token[1..].to_string());
        } else if token.starts_with("-#") && token.len() > 2 {
            let raw = &token[2..];
            if raw.contains(',') {
                for part in raw.split(',') {
                    let t = part.trim();
                    if !t.is_empty() { tags_not.push(t.to_string()); }
                }
            } else {
                tags_not.push(raw.to_string());
            }
        } else if token.starts_with('#') && token.len() > 1 {
            let raw = &token[1..];
            if raw.contains(',') {
                for part in raw.split(',') {
                    let t = part.trim();
                    if !t.is_empty() { tags_or.push(t.to_string()); }
                }
            } else {
                tags_and.push(raw.to_string());
            }
        } else if let Some((prefix, ops)) = parse_date_clause(token) {
            for op in ops {
                dates.push(DateClause { prefix: prefix.clone(), op });
            }
        } else {
            fulltext_words.push(token.clone());
        }
    }

    ParsedQuery {
        tags_and,
        tags_or,
        tags_not,
        dates,
        fulltext: if fulltext_words.is_empty() {
            None
        } else {
            Some(fulltext_words.join(" "))
        },
        views,
        sort_by,
        alternatives: vec![],
    }
}

fn parse_sort(token: &str) -> Option<SortDirective> {
    if !token.starts_with('>') || token.len() < 2 { return None; }
    match &token[1..] {
        "due" => Some(SortDirective::Due),
        "created" => Some(SortDirective::Created),
        _ => None,
    }
}

/// Tokenize input, respecting double-quotes for literal text.
fn tokenize(input: &str) -> Vec<String> {
    let mut tokens = Vec::new();
    let mut buf = String::new();
    let mut in_quote = false;

    for c in input.chars() {
        match c {
            '"' => in_quote = !in_quote,
            ' ' if !in_quote => {
                if !buf.is_empty() {
                    tokens.push(buf.clone());
                    buf.clear();
                }
            }
            _ => buf.push(c),
        }
    }
    if !buf.is_empty() {
        tokens.push(buf);
    }
    tokens
}

/// Check if a token is a date clause (prefix:period) and parse it.
fn parse_date_clause(token: &str) -> Option<(String, Vec<DateOp>)> {
    let colon = token.find(':')?;
    if colon == 0 || colon == token.len() - 1 {
        return None;
    }
    let prefix = token[..colon].to_string();
    if prefix != "*" && !prefix.chars().all(|c| c.is_ascii_lowercase() || c == '-') {
        return None;
    }
    let periods = &token[colon + 1..];
    let ops: Vec<DateOp> = periods.split(',')
        .filter_map(|p| parse_date_op(p.trim()))
        .collect();
    if ops.is_empty() { None } else { Some((prefix, ops)) }
}

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
    fn test_tokenize_simple() {
        let t = tokenize("hello world");
        assert_eq!(t, vec!["hello", "world"]);
    }

    #[test]
    fn test_tokenize_quoted() {
        let t = tokenize(r#"#work "fix login bug" -#blocked"#);
        assert_eq!(t, vec!["#work", "fix login bug", "-#blocked"]);
    }

    #[test]
    fn test_parse_tags() {
        let q = parse_query("#urgent #work/rtd -#blocked");
        assert_eq!(q.tags_and, vec!["urgent", "work/rtd"]);
        assert_eq!(q.tags_not, vec!["blocked"]);
    }

    #[test]
    fn test_parse_date() {
        let q = parse_query("done:this-week");
        assert_eq!(q.dates.len(), 1);
        assert_eq!(q.dates[0].prefix, "done");
        assert!(matches!(q.dates[0].op, DateOp::ThisWeek));
    }

    #[test]
    fn test_parse_fulltext() {
        let q = parse_query("fix login");
        assert_eq!(q.fulltext.as_deref(), Some("fix login"));
    }

    #[test]
    fn test_parse_view() {
        let q = parse_query("@Work #urgent");
        assert_eq!(q.views, vec!["Work"]);
        assert_eq!(q.tags_and, vec!["urgent"]);
    }

    #[test]
    fn test_parse_mixed() {
        let q = parse_query("#urgent done:today -#blocked @Work \"fix login\"");
        assert_eq!(q.tags_and, vec!["urgent"]);
        assert_eq!(q.tags_not, vec!["blocked"]);
        assert_eq!(q.dates.len(), 1);
        assert_eq!(q.views, vec!["Work"]);
        assert!(q.fulltext.as_deref().unwrap().contains("fix login"));
    }

    #[test]
    fn test_is_empty() {
        assert!(parse_query("").is_empty());
        assert!(!parse_query("#work").is_empty());
    }

    #[test]
    fn test_parse_or_tags() {
        let q = parse_query("#urgent,life");
        assert_eq!(q.tags_or, vec!["urgent", "life"]);
        assert!(q.tags_and.is_empty());
    }

    #[test]
    fn test_parse_or_with_and() {
        let q = parse_query("#work #urgent,life");
        assert_eq!(q.tags_and, vec!["work"]);
        assert_eq!(q.tags_or, vec!["urgent", "life"]);
    }

    #[test]
    fn test_parse_date_or() {
        let q = parse_query("done:this-week,today");
        assert_eq!(q.dates.len(), 2);
        assert_eq!(q.dates[0].prefix, "done");
        assert!(matches!(q.dates[0].op, DateOp::ThisWeek));
        assert_eq!(q.dates[1].prefix, "done");
        assert!(matches!(q.dates[1].op, DateOp::Today));
    }

    #[test]
    fn test_parse_exclude_or() {
        let q = parse_query("-#blocked,done");
        assert_eq!(q.tags_not, vec!["blocked", "done"]);
    }

    #[test]
    fn test_parse_alternatives() {
        let q = parse_query("#urgent | done:today");
        assert_eq!(q.tags_and, vec!["urgent"]);
        assert_eq!(q.alternatives.len(), 1);
        assert_eq!(q.alternatives[0].dates.len(), 1);
        assert_eq!(q.alternatives[0].dates[0].prefix, "done");
    }

    #[test]
    fn test_parse_sort() {
        let q = parse_query("#work >due");
        assert_eq!(q.tags_and, vec!["work"]);
        assert!(matches!(q.sort_by, Some(SortDirective::Due)));
    }

    #[test]
    fn test_parse_alternatives_with_sort() {
        let q = parse_query("#urgent >due | #bug >created");
        assert_eq!(q.tags_and, vec!["urgent"]);
        assert!(matches!(q.sort_by, Some(SortDirective::Due)));
        assert_eq!(q.alternatives.len(), 1);
        assert_eq!(q.alternatives[0].tags_and, vec!["bug"]);
        assert!(matches!(q.alternatives[0].sort_by, Some(SortDirective::Created)));
    }

    #[test]
    fn test_parse_wildcard_date() {
        let q = parse_query("*:today");
        assert_eq!(q.dates.len(), 1);
        assert_eq!(q.dates[0].prefix, "*");
        assert!(matches!(q.dates[0].op, DateOp::Today));
    }
}
