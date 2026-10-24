// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-3.0-or-later

pub mod host {
    pub fn get_hostname() -> Result<String, std::io::Error> {
        let name = std::fs::read_to_string("/proc/sys/kernel/hostname")?;
        let name = name.trim();
        if name.is_empty() {
            return Err(std::io::Error::other("no host name"));
        }
        Ok(name.to_string())
    }
}
