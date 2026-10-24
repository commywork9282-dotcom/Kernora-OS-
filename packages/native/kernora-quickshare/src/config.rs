// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-3.0-or-later

use std::fs;
use std::path::PathBuf;

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Mode {
    Everyone,
    Hidden,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(default)]
pub struct Config {
    pub enabled: bool,
    pub visibility: Mode,
    pub name: String,
    pub folder: String,
    pub ask_nearby: bool,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            enabled: true,
            visibility: Mode::Hidden,
            name: default_name(),
            folder: String::new(),
            ask_nearby: true,
        }
    }
}

fn config_path() -> PathBuf {
    let base = std::env::var_os("XDG_CONFIG_HOME")
        .map(PathBuf::from)
        .filter(|path| path.is_absolute())
        .unwrap_or_else(|| home().join(".config"));
    base.join("kernora").join("quickshare.json")
}

pub fn home() -> PathBuf {
    std::env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("/"))
}

fn default_name() -> String {
    if let Ok(text) = fs::read_to_string("/etc/machine-info") {
        for line in text.lines() {
            if let Some(value) = line.strip_prefix("PRETTY_HOSTNAME=") {
                let value = value.trim().trim_matches('"').trim();
                if !value.is_empty() {
                    return value.to_string();
                }
            }
        }
    }
    fs::read_to_string("/etc/hostname")
        .ok()
        .map(|name| name.trim().to_string())
        .filter(|name| !name.is_empty())
        .unwrap_or_else(|| "Kernora".to_string())
}

impl Config {
    pub fn load() -> Self {
        let mut config: Config = fs::read(config_path())
            .ok()
            .and_then(|bytes| serde_json::from_slice(&bytes).ok())
            .unwrap_or_default();
        config.name = clean_name(&config.name).unwrap_or_else(default_name);
        config
    }

    pub fn save(&self) {
        let path = config_path();
        if let Some(parent) = path.parent() {
            let _ = fs::create_dir_all(parent);
        }
        let temporary = path.with_extension("json.new");
        match serde_json::to_vec_pretty(self) {
            Ok(bytes) => {
                if fs::write(&temporary, bytes).is_ok() {
                    let _ = fs::rename(&temporary, &path);
                }
            }
            Err(err) => warn!("could not save the settings: {err}"),
        }
    }

    pub fn download_folder(&self) -> Option<PathBuf> {
        let folder = PathBuf::from(&self.folder);
        (!self.folder.is_empty() && folder.is_absolute()).then_some(folder)
    }
}

pub fn clean_name(name: &str) -> Option<String> {
    let name: String = name.chars().filter(|c| !c.is_control()).collect();
    let name = name.trim();
    if name.is_empty() {
        return None;
    }
    let mut cut = String::new();
    for c in name.chars() {
        if cut.len() + c.len_utf8() > 60 {
            break;
        }
        cut.push(c);
    }
    Some(cut)
}
