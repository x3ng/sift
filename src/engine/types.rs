//! Shared types for the filter/combinator engine.

use chrono::{NaiveDate, NaiveDateTime};

/// Date period operations used by both the combinator parser and the filter engine.
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

/// Parse a date string, trying datetime format first then date-only.
/// Used by index, filter, and combinator modules.
pub fn parse_date_value(s: &str) -> Option<NaiveDateTime> {
    NaiveDateTime::parse_from_str(s, "%Y-%m-%dT%H:%M")
        .or_else(|_| NaiveDateTime::parse_from_str(s, "%Y-%m-%dT%H:%M:%S"))
        .or_else(|_| {
            NaiveDate::parse_from_str(s, "%Y-%m-%d")
                .map(|d| d.and_hms_opt(0, 0, 0).unwrap())
        })
        .ok()
}

/// Parse a tag's date value by stripping the prefix and parsing the remainder.
pub fn parse_tag_date(tag: &str, prefix: &str) -> Option<NaiveDateTime> {
    tag.strip_prefix(prefix).and_then(parse_date_value)
}
