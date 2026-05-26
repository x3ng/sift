use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Entry {
    pub id: Uuid,
    pub name: String,
    pub value: String,
    pub tags: Vec<String>,
}

impl Entry {
    pub fn new(name: String, value: String, tags: Vec<String>) -> Self {
        Self {
            id: Uuid::new_v4(),
            name,
            value,
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

/// Reserved characters that cannot start a tag name.
const RESERVED: &[char] = &['#', '-', '&', '$'];

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

/// Validate that a tag name does not start with reserved characters.
pub fn validate_tag(tag: &str) -> Result<(), String> {
    if let Some(first) = tag.chars().next()
        && RESERVED.contains(&first)
    {
        return Err(format!("tag '{}' cannot start with '{}'", tag, first));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_new_entry_strips_hash_and_dedup() {
        let e = Entry::new(
            "test".into(),
            String::new(),
            vec!["#urgent".into(), "urgent".into(), "life".into()],
        );
        assert_eq!(e.name, "test");
        assert_eq!(e.tags, vec!["life", "urgent"]);
    }

    #[test]
    fn test_is_done() {
        let e = Entry::new(
            "x".into(),
            String::new(),
            vec!["done/2026-01-01T00:00".into()],
        );
        assert!(e.is_done());
    }

    #[test]
    fn test_has_tag_wildcard() {
        let e = Entry::new(
            "x".into(),
            String::new(),
            vec!["work/rtd".into(), "urgent".into()],
        );
        assert!(e.has_tag("work/*"));
        assert!(!e.has_tag("life/*"));
    }

    #[test]
    fn test_value_is_string() {
        let e = Entry::new("test".into(), "hello world".into(), vec![]);
        assert_eq!(e.value, "hello world");
    }

    #[test]
    fn test_validate_tag() {
        assert!(validate_tag("work").is_ok());
        assert!(validate_tag("work/urgent").is_ok());
        assert!(validate_tag("#tag").is_err());
        assert!(validate_tag("-tag").is_err());
        assert!(validate_tag("&tag").is_err());
        assert!(validate_tag("$tag").is_err());
    }
}
