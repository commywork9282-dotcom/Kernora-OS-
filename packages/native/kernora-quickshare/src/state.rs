// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-3.0-or-later

use std::path::Path;
use std::time::{Duration, Instant};

use rqs_lib::channel::{ChannelMessage, Message, TransferKind};
use rqs_lib::hdl::info::{TransferPayload, TransferPayloadKind};
use rqs_lib::{DeviceType, EndpointInfo, TransferState};
use serde::Serialize;

#[derive(Debug, Clone, Serialize)]
pub struct Device {
    pub id: String,
    pub name: String,
    pub kind: &'static str,
    #[serde(skip)]
    pub addr: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum Phase {
    Connecting,
    Waiting,
    Transferring,
    Finished,
    Rejected,
    Cancelled,
    Failed,
}

impl Phase {
    pub fn is_over(self) -> bool {
        matches!(
            self,
            Phase::Finished | Phase::Rejected | Phase::Cancelled | Phase::Failed
        )
    }
}

#[derive(Debug, Clone, Serialize)]
pub struct Transfer {
    pub id: String,
    pub outgoing: bool,
    pub device: String,
    pub device_kind: &'static str,
    pub phase: Phase,
    pub pin: String,
    pub kind: &'static str,
    pub files: Vec<String>,
    pub preview: String,
    pub text: String,
    pub total: u64,
    pub done: u64,
    #[serde(skip)]
    pub addr: String,
    #[serde(skip)]
    pub updated: Option<Instant>,
    #[serde(skip)]
    pub wifi: Option<(String, String)>,
}

pub fn device_kind(kind: &DeviceType) -> &'static str {
    match kind {
        DeviceType::Phone => "phone",
        DeviceType::Tablet => "tablet",
        DeviceType::Laptop => "computer",
        _ => "unknown",
    }
}

pub fn device_from_endpoint(info: &EndpointInfo) -> Option<Device> {
    let ip = info.ip.as_ref()?;
    let port = info.port.as_ref()?;
    let addr = if ip.contains(':') {
        format!("[{ip}]:{port}")
    } else {
        format!("{ip}:{port}")
    };
    Some(Device {
        id: info.id.clone(),
        name: info
            .name
            .clone()
            .filter(|name| !name.trim().is_empty())
            .unwrap_or_else(|| "Unknown device".to_string()),
        kind: info.rtype.as_ref().map(device_kind).unwrap_or("unknown"),
        addr,
    })
}

fn phase(state: &TransferState, outgoing: bool) -> Phase {
    match state {
        TransferState::WaitingForUserConsent => Phase::Waiting,
        TransferState::SentIntroduction if outgoing => Phase::Waiting,
        TransferState::ReceivingFiles | TransferState::SendingFiles => Phase::Transferring,
        TransferState::Finished => Phase::Finished,
        TransferState::Rejected => Phase::Rejected,
        TransferState::Cancelled => Phase::Cancelled,
        TransferState::Disconnected => Phase::Failed,
        _ => Phase::Connecting,
    }
}

fn file_name(path: &str) -> String {
    Path::new(path)
        .file_name()
        .map(|name| name.to_string_lossy().into_owned())
        .unwrap_or_else(|| path.to_string())
}

impl Transfer {
    pub fn outgoing(id: &str, device: &Device, files: &[String]) -> Self {
        Self {
            id: id.to_string(),
            outgoing: true,
            device: device.name.clone(),
            device_kind: device.kind,
            phase: Phase::Connecting,
            pin: String::new(),
            kind: "files",
            files: files.iter().map(|path| file_name(path)).collect(),
            preview: String::new(),
            text: String::new(),
            total: 0,
            done: 0,
            addr: device.addr.clone(),
            updated: Some(Instant::now()),
            wifi: None,
        }
    }

    pub fn incoming(id: &str) -> Self {
        Self {
            id: id.to_string(),
            outgoing: false,
            device: String::new(),
            device_kind: "unknown",
            phase: Phase::Connecting,
            pin: String::new(),
            kind: "files",
            files: Vec::new(),
            preview: String::new(),
            text: String::new(),
            total: 0,
            done: 0,
            addr: id.to_string(),
            updated: Some(Instant::now()),
            wifi: None,
        }
    }

    pub fn apply(&mut self, message: &ChannelMessage) -> bool {
        let Message::Client(client) = &message.msg else {
            return false;
        };
        let outgoing = client.kind == TransferKind::Outbound;
        let mut changed = false;
        if let Some(state) = &client.state {
            let mut next = phase(state, outgoing);
            if outgoing && self.phase == Phase::Waiting && next == Phase::Failed {
                next = Phase::Rejected;
            }
            let keep = self.phase.is_over() && next == Phase::Failed;
            if next != self.phase && !keep {
                self.phase = next;
                changed = true;
            }
        }
        if let Some(meta) = &client.metadata {
            if let Some(source) = &meta.source {
                if !source.name.is_empty() && self.device != source.name {
                    self.device = source.name.clone();
                    changed = true;
                }
                let kind = device_kind(&source.device_type);
                if kind != "unknown" {
                    self.device_kind = kind;
                }
            }
            if let Some(pin) = &meta.pin_code {
                if &self.pin != pin {
                    self.pin = pin.clone();
                    changed = true;
                }
            }
            self.kind = match meta.payload_kind {
                TransferPayloadKind::Files => "files",
                TransferPayloadKind::Text => "text",
                TransferPayloadKind::Url => "url",
                TransferPayloadKind::WiFi => "wifi",
            };
            if let Some(preview) = &meta.payload_preview {
                self.preview = preview.clone();
            }
            match &meta.payload {
                Some(TransferPayload::Files(files)) if !files.is_empty() => {
                    self.files = if outgoing {
                        files.iter().map(|path| file_name(path)).collect()
                    } else {
                        files.clone()
                    };
                }
                Some(TransferPayload::Text(text)) | Some(TransferPayload::Url(text)) => {
                    self.text = text.clone();
                }
                Some(TransferPayload::Wifi { ssid, password, .. }) => {
                    self.wifi = Some((ssid.clone(), password.clone()));
                    self.preview = ssid.clone();
                }
                _ => {}
            }
            if meta.total_bytes != self.total || meta.ack_bytes != self.done {
                self.total = meta.total_bytes;
                self.done = meta.ack_bytes;
                changed = true;
            }
        }
        self.updated = Some(Instant::now());
        changed
    }

    pub fn unsafe_names(&self) -> bool {
        !self.outgoing
            && self.files.iter().any(|name| {
                name.is_empty()
                    || name == "."
                    || name == ".."
                    || name.contains('/')
                    || name.contains('\0')
            })
    }

    pub fn stale(&self, now: Instant) -> bool {
        self.phase.is_over()
            && self
                .updated
                .map(|time| now.duration_since(time) > Duration::from_secs(600))
                .unwrap_or(true)
    }
}
