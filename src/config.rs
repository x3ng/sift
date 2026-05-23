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

fn default_editor() -> String { "vim".into() }
fn default_true() -> bool { true }
fn default_datetime_fmt() -> String { "%Y-%m-%d %H:%M".into() }
fn default_date_fmt() -> String { "%Y-%m-%d".into() }

fn default_data_dir() -> PathBuf {
    ProjectDirs::from("", "", "sift")
        .expect("could not determine project directories")
        .data_dir()
        .to_path_buf()
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
        let proj = ProjectDirs::from("", "", "sift")
            .expect("could not determine project directories");
        Self {
            editor: default_editor(),
            data_dir: proj.data_dir().to_path_buf(),
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
    let dirs = ProjectDirs::from("", "", "sift")
        .expect("could not determine project directories");
    dirs.config_dir().join("config.toml")
}
