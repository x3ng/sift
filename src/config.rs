use directories::ProjectDirs;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    #[serde(default = "default_editor")]
    pub editor: String,

    #[serde(default = "default_data_dir")]
    pub data_dir: PathBuf,

    #[serde(default)]
    pub tags: TagsConfig,

    #[serde(default)]
    pub display: DisplayConfig,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct TagsConfig {
    #[serde(default)]
    pub priority_order: Vec<String>,

    #[serde(default = "default_date_prefixes")]
    pub date_prefixes: HashMap<String, String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DisplayConfig {
    #[serde(default = "default_datetime_fmt")]
    pub datetime_format: String,
    #[serde(default = "default_date_fmt")]
    pub date_format: String,
    #[serde(default = "default_true")]
    pub color: bool,
}

fn default_editor() -> String {
    "vim".into()
}
fn default_true() -> bool {
    true
}
fn default_datetime_fmt() -> String {
    "%Y-%m-%d %H:%M".into()
}
fn default_date_fmt() -> String {
    "%Y-%m-%d".into()
}

fn default_data_dir() -> PathBuf {
    if let Some(proj) = ProjectDirs::from("", "", "sift") {
        proj.data_dir().to_path_buf()
    } else {
        // Fallback when XDG/desktop dirs can't be determined
        dirs_fallback()
    }
}

fn dirs_fallback() -> PathBuf {
    std::env::var("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from("."))
        .join(".local/share/sift")
}

fn default_date_prefixes() -> HashMap<String, String> {
    let mut m = HashMap::new();
    m.insert("created/".into(), "%Y-%m-%dT%H:%M".into());
    m.insert("done/".into(), "%Y-%m-%dT%H:%M".into());
    m.insert("due/".into(), "%Y-%m-%d".into());
    m
}

impl Default for DisplayConfig {
    fn default() -> Self {
        Self {
            datetime_format: default_datetime_fmt(),
            date_format: default_date_fmt(),
            color: true,
        }
    }
}

impl Config {
    pub fn load() -> Result<Self, Box<dyn std::error::Error>> {
        let path = config_path();
        if path.exists() {
            let text = std::fs::read_to_string(&path)?;
            Ok(toml::from_str(&text)?)
        } else {
            let cfg = Self::default_with_paths();
            cfg.save()?;
            Ok(cfg)
        }
    }

    pub fn default_with_paths() -> Self {
        Self {
            editor: default_editor(),
            data_dir: default_data_dir(),
            tags: TagsConfig::default(),
            display: DisplayConfig::default(),
        }
    }

    pub fn save(&self) -> Result<(), Box<dyn std::error::Error>> {
        let path = config_path();
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)?;
        }
        let text = toml::to_string_pretty(self)?;
        std::fs::write(path, text)?;
        Ok(())
    }

    pub fn entries_path(&self) -> PathBuf {
        self.data_dir.join("entries.jsonl")
    }

    pub fn backup_dir(&self) -> PathBuf {
        self.data_dir.join(".backup")
    }
}

fn config_path() -> PathBuf {
    if let Some(proj) = ProjectDirs::from("", "", "sift") {
        proj.config_dir().join("config.toml")
    } else {
        dirs_fallback().join("config.toml")
    }
}
