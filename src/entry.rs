use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(tag = "type")]
pub enum Body {
    #[serde(rename = "text")]
    Text { content: String },
    #[serde(rename = "file")]
    File { path: String },
    #[serde(rename = "empty")]
    Empty,
}

impl Body {
    pub fn text(&self) -> Option<&str> {
        match self {
            Body::Text { content } => Some(content),
            _ => None,
        }
    }

    pub fn searchable_text(&self) -> String {
        match self {
            Body::Text { content } => content.clone(),
            Body::File { path } => path.clone(),
            Body::Empty => String::new(),
        }
    }

    pub fn file_path(&self) -> Option<&str> {
        match self {
            Body::File { path } => Some(path),
            _ => None,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Entry {
    pub id: Uuid,
    pub name: String,
    pub body: Body,
    pub tags: Vec<String>,
}

impl Entry {
    pub fn new(name: String, body: Body, tags: Vec<String>) -> Self {
        Self {
            id: Uuid::new_v4(),
            name,
            body,
            tags: normalize_tags(tags),
        }
    }

    pub fn id_prefix(&self) -> String {
        self.id.to_string().chars().take(8).collect()
    }

    pub fn is_done(&self) -> bool {
        self.tags.iter().any(|t| t.starts_with("done/"))
    }

    pub fn has_tag(&self, pattern: &str) -> bool {
        if pattern.ends_with('*') {
            let prefix = pattern.trim_end_matches('*');
            self.tags.iter().any(|t| t.starts_with(prefix))
        } else {
            self.tags.iter().any(|t| t == pattern)
        }
    }
}

fn normalize_tags(tags: Vec<String>) -> Vec<String> {
    let mut result: Vec<String> = tags
        .into_iter()
        .map(|t| t.trim().trim_start_matches('#').to_string())
        .filter(|t| !t.is_empty())
        .collect();
    result.sort();
    result.dedup();
    result
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_new_entry_strips_hash_and_dedup() {
        let e = Entry::new(
            "test".into(),
            Body::Empty,
            vec!["#urgent".into(), "urgent".into(), "life".into()],
        );
        assert_eq!(e.name, "test");
        assert_eq!(e.tags, vec!["life", "urgent"]);
    }

    #[test]
    fn test_is_done() {
        let e = Entry::new(
            "x".into(),
            Body::Empty,
            vec!["done/2026-01-01T00:00".into()],
        );
        assert!(e.is_done());
    }

    #[test]
    fn test_has_tag_wildcard() {
        let e = Entry::new(
            "x".into(),
            Body::Empty,
            vec!["work/rtd".into(), "urgent".into()],
        );
        assert!(e.has_tag("work/*"));
        assert!(!e.has_tag("life/*"));
    }

    #[test]
    fn test_body_text() {
        let t = Body::Text { content: "hello".into() };
        assert_eq!(t.text(), Some("hello"));
        let f = Body::File { path: "files/x.png".into() };
        assert_eq!(f.file_path(), Some("files/x.png"));
        assert_eq!(f.text(), None);
        assert_eq!(Body::Empty.text(), None);
    }

    #[test]
    fn test_body_serde() {
        let t = Body::Text { content: "hello".into() };
        let json = serde_json::to_string(&t).unwrap();
        assert!(json.contains(r#""type":"text""#));
        let back: Body = serde_json::from_str(&json).unwrap();
        assert_eq!(t, back);
    }
}
