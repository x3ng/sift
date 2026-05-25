//! FFI-compatible API layer over SiftCore.
//!
//! DTOs use String IDs instead of uuid::Uuid, and derive Serialize/Deserialize
//! for JSON-passing over the dart:ffi boundary.

use sift::api::SiftCore;
use sift::engine::combinator;
use sift::entry::{Body, Entry};
use serde::{Deserialize, Serialize};

// ── DTOs ──────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum FrbBody {
    #[serde(rename = "text")]
    Text { content: String },
    #[serde(rename = "file")]
    File { path: String },
    #[serde(rename = "empty")]
    Empty,
}

impl FrbBody {
    pub fn text(&self) -> Option<&str> {
        match self {
            FrbBody::Text { content } => Some(content),
            _ => None,
        }
    }
}

impl From<Body> for FrbBody {
    fn from(b: Body) -> Self {
        match b {
            Body::Text { content } => FrbBody::Text { content },
            Body::File { path } => FrbBody::File { path },
            Body::Empty => FrbBody::Empty,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FrbEntry {
    pub id: String,
    pub name: String,
    pub body: FrbBody,
    pub tags: Vec<String>,
}

impl FrbEntry {
    pub fn id_prefix(&self) -> String {
        self.id.chars().take(8).collect()
    }
}

impl From<Entry> for FrbEntry {
    fn from(e: Entry) -> Self {
        FrbEntry {
            id: e.id.to_string(),
            name: e.name,
            body: FrbBody::from(e.body),
            tags: e.tags,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FrbParsedQuery {
    pub tags_and: Vec<String>,
    pub tags_or: Vec<String>,
    pub tags_not: Vec<String>,
    pub dates: Vec<FrbDateClause>,
    pub fulltext: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FrbDateClause {
    pub prefix: String,
    pub op: FrbDateOp,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub enum FrbDateOp {
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

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FrbStatsData {
    pub total: usize,
    pub active: usize,
    pub done: usize,
    pub unique_tags: usize,
}

// ── conversions ───────────────────────────────────────────────────

impl From<combinator::ParsedQuery> for FrbParsedQuery {
    fn from(pq: combinator::ParsedQuery) -> Self {
        FrbParsedQuery {
            tags_and: pq.tags_and,
            tags_or: pq.tags_or,
            tags_not: pq.tags_not,
            dates: pq.dates.into_iter().map(|d| FrbDateClause {
                prefix: d.prefix,
                op: d.op.into(),
            }).collect(),
            fulltext: pq.fulltext,
        }
    }
}

impl From<FrbBody> for Body {
    fn from(b: FrbBody) -> Self {
        match b {
            FrbBody::Text { content } => Body::Text { content },
            FrbBody::File { path } => Body::File { path },
            FrbBody::Empty => Body::Empty,
        }
    }
}

impl From<combinator::DateOp> for FrbDateOp {
    fn from(op: combinator::DateOp) -> Self {
        match op {
            combinator::DateOp::Today => FrbDateOp::Today,
            combinator::DateOp::Yesterday => FrbDateOp::Yesterday,
            combinator::DateOp::Tomorrow => FrbDateOp::Tomorrow,
            combinator::DateOp::ThisWeek => FrbDateOp::ThisWeek,
            combinator::DateOp::LastWeek => FrbDateOp::LastWeek,
            combinator::DateOp::NextWeek => FrbDateOp::NextWeek,
            combinator::DateOp::ThisMonth => FrbDateOp::ThisMonth,
            combinator::DateOp::LastMonth => FrbDateOp::LastMonth,
            combinator::DateOp::Overdue => FrbDateOp::Overdue,
        }
    }
}

// ── wrapper ───────────────────────────────────────────────────────

pub struct SiftCoreWrapper {
    inner: SiftCore,
}

impl SiftCoreWrapper {
    pub fn new(data_dir: Option<String>) -> Result<Self, String> {
        SiftCore::new(data_dir).map(|inner| Self { inner })
    }

    // ── read-only ──────────────────────────────────────────────

    pub fn list_parsed(&self, query: String, show_done: bool) -> Result<Vec<FrbEntry>, String> {
        self.inner.list_parsed(&query, show_done)
            .map(|v| v.into_iter().map(FrbEntry::from).collect())
    }

    pub fn all_tags(&self) -> Vec<(String, usize)> {
        self.inner.all_tags()
    }

    pub fn search(&self, query: String) -> Vec<FrbEntry> {
        self.inner.search(query).into_iter().map(FrbEntry::from).collect()
    }

    pub fn get_entry(&self, id_prefix: String) -> Option<FrbEntry> {
        self.inner.get_entry(&id_prefix).map(FrbEntry::from)
    }

    pub fn stats(&self) -> FrbStatsData {
        let s = self.inner.stats();
        FrbStatsData {
            total: s.total,
            active: s.active,
            done: s.done,
            unique_tags: s.unique_tags,
        }
    }

    // ── mutating ───────────────────────────────────────────────

    pub fn add(&mut self, name: String, body: FrbBody, tags: Vec<String>) -> Result<FrbEntry, String> {
        let b: Body = match body {
            FrbBody::File { ref path } => {
                let managed = self.inner.store.import_file(std::path::Path::new(path))
                    .map_err(|e| e.to_string())?;
                Body::File { path: managed }
            }
            other => other.into(),
        };
        self.inner.add(name, b, tags).map(FrbEntry::from)
    }



    pub fn edit(&mut self, id: String, name: Option<String>, body: Option<FrbBody>) -> Result<bool, String> {
        self.inner.edit(id, name, body.map(|b| b.into()))
    }

    pub fn delete(&mut self, id: String) -> Result<bool, String> {
        self.inner.delete(id)
    }

    pub fn tag(&mut self, id: String, add_tags: Vec<String>, rm_tags: Vec<String>) -> Result<bool, String> {
        self.inner.tag(id, add_tags, rm_tags)
    }

    pub fn rename_tag(&mut self, old: String, new: String) -> Result<usize, String> {
        self.inner.rename_tag(&old, &new)
    }

    // ── batch / io ─────────────────────────────────────────────

    pub fn batch_delete(&mut self, id_prefixes: Vec<String>) -> Result<usize, String> {
        self.inner.batch_delete(id_prefixes)
    }

    pub fn batch_tag(&mut self, id_prefixes: Vec<String>, add_tags: Vec<String>, rm_tags: Vec<String>) -> Result<usize, String> {
        self.inner.batch_tag(id_prefixes, add_tags, rm_tags)
    }

    pub fn export_to(&self, path: String) -> Result<(), String> {
        self.inner.export_to(path)
    }

    pub fn import_from(&mut self, path: String) -> Result<usize, String> {
        self.inner.import_from(path)
    }
}

// ── standalone functions ──────────────────────────────────────────

/// Parse a combinator query string. Stateless — no SiftCore needed.
pub fn parse_query(input: String) -> FrbParsedQuery {
    combinator::parse_query(&input).into()
}
