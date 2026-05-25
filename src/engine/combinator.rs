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

/// Structured result of parsing a combinator query string.
#[derive(Debug, Clone, Default)]
pub struct ParsedQuery {
    pub tags_and: Vec<String>,
    pub tags_or: Vec<String>,
    pub tags_not: Vec<String>,
    pub dates: Vec<DateClause>,
    pub fulltext: Option<String>,
    pub views: Vec<String>,
}

impl ParsedQuery {
    pub fn is_empty(&self) -> bool {
        self.tags_and.is_empty()
            && self.tags_or.is_empty()
            && self.tags_not.is_empty()
            && self.dates.is_empty()
            && self.fulltext.is_none()
            && self.views.is_empty()
    }
}

#[derive(Debug, Clone)]
pub struct DateClause {
    pub prefix: String,
    pub op: DateOp,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum DateOp {
    Today,
    Yesterday,
    Tomorrow,
    ThisWeek,
    LastWeek,
    NextWeek,
    ThisMonth,
    LastMonth,
    Overdue,
}

/// Parse a combinator query string into a structured query.
/// @view references are collected into `ParsedQuery::views` for later resolution.
pub fn parse_query(input: &str) -> ParsedQuery {
    let mut tags_and = Vec::new();
    let mut tags_or = Vec::new();
    let mut tags_not = Vec::new();
    let mut dates = Vec::new();
    let mut views = Vec::new();
    let mut fulltext_words = Vec::new();

    let tokens = tokenize(input);

    for token in &tokens {
        if token.starts_with("@") && token.len() > 1 {
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
    if !prefix.chars().all(|c| c.is_ascii_lowercase() || c == '-') {
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
}
