// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-3.0-or-later

#[macro_use]
extern crate log;

mod bus;
mod config;
mod desktop;
mod state;
mod text;

use std::collections::{BTreeMap, HashMap};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use dbus::nonblock::SyncConnection;
use rqs_lib::channel::{ChannelMessage, Message, TransferAction, TransferKind};
use rqs_lib::{EndpointInfo, OutboundPayload, RQS, SendInfo, Visibility};
use serde_json::json;
use tokio::sync::{broadcast, mpsc};
use tracing_subscriber::EnvFilter;

use config::{Config, Mode};
use desktop::{Desktop, Note};
use state::{Device, Phase, Transfer};

const TEMPORARY: Duration = Duration::from_secs(600);
const DISCOVERY: Duration = Duration::from_secs(90);
const NEARBY_PAUSE: Duration = Duration::from_secs(180);
const FLUSH: Duration = Duration::from_millis(250);

#[derive(Debug)]
pub enum Command {
    SetVisibility(String),
    SetName(String),
    SetFolder(String),
    SetAskNearby(bool),
    StartDiscovery,
    StopDiscovery,
    Send(String, String, Vec<String>),
    Accept(String),
    Decline(String),
    Cancel(String),
    Dismiss(String),
    NotificationAction(u32, String),
    NotificationClosed(u32, u32),
    JobCancelled(String),
}

enum NoteKind {
    Consent(String),
    Received(String),
    Nearby,
}

struct Service {
    rqs: RQS,
    send_tx: mpsc::Sender<SendInfo>,
    ble_rx: broadcast::Receiver<()>,
    device_tx: broadcast::Sender<EndpointInfo>,
    config: Config,
    temporary_until: Option<Instant>,
    discovering_until: Option<Instant>,
    devices: BTreeMap<String, Device>,
    transfers: Vec<Transfer>,
    notes: HashMap<u32, NoteKind>,
    jobs: HashMap<String, String>,
    last_nearby: Option<Instant>,
    restart_pending: bool,
    dirty: bool,
    desktop: Desktop,
    conn: Arc<SyncConnection>,
    shared: Arc<Mutex<String>>,
}

#[tokio::main]
async fn main() -> Result<(), anyhow::Error> {
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::try_from_default_env().unwrap_or_else(|_| {
            EnvFilter::new("info,mdns_sd=error,polling=error,neli=error,bluez_async=error,btleplug=error")
        }))
        .with_writer(std::io::stderr)
        .init();

    let (resource, conn) = dbus_tokio::connection::new_session_sync()?;
    tokio::spawn(async move {
        let err = resource.await;
        error!("lost the session bus: {err}");
        std::process::exit(1);
    });

    let reply = conn.request_name(bus::NAME, false, true, true).await?;
    if reply != dbus::nonblock::stdintf::org_freedesktop_dbus::RequestNameReply::PrimaryOwner {
        info!("Quick Share is already running");
        return Ok(());
    }

    let (commands_tx, mut commands_rx) = mpsc::unbounded_channel();
    let shared = Arc::new(Mutex::new(String::from("{}")));
    let desktop = Desktop::new(conn.clone(), commands_tx.clone()).await?;

    let config = Config::load();
    let mut rqs = RQS::new(
        visibility_for(config.visibility),
        None,
        config.download_folder(),
        Some(config.name.clone()),
    );
    let (send_tx, ble_rx) = rqs.run().await?;
    let mut messages = rqs.message_sender.subscribe();
    let (device_tx, mut devices_rx) = broadcast::channel(32);

    let mut service = Service {
        rqs,
        send_tx,
        ble_rx,
        device_tx,
        config,
        temporary_until: None,
        discovering_until: None,
        devices: BTreeMap::new(),
        transfers: Vec::new(),
        notes: HashMap::new(),
        jobs: HashMap::new(),
        last_nearby: None,
        restart_pending: false,
        dirty: true,
        desktop,
        conn: conn.clone(),
        shared: shared.clone(),
    };
    service.flush();
    bus::serve(&conn, shared, commands_tx);
    info!("Quick Share is ready as {}", service.config.name);

    let mut tick = tokio::time::interval(FLUSH);
    let mut terminate = tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())?;
    loop {
        tokio::select! {
            Some(command) = commands_rx.recv() => service.command(command).await,
            message = messages.recv() => match message {
                Ok(message) => service.message(message).await,
                Err(broadcast::error::RecvError::Lagged(_)) => {}
                Err(broadcast::error::RecvError::Closed) => break,
            },
            device = devices_rx.recv() => {
                if let Ok(device) = device {
                    service.device(device);
                }
            }
            nearby = service.ble_rx.recv() => {
                if let Ok(()) | Err(broadcast::error::RecvError::Lagged(_)) = nearby {
                    service.nearby().await;
                }
            }
            _ = tick.tick() => service.tick().await,
            _ = tokio::signal::ctrl_c() => break,
            _ = terminate.recv() => break,
        }
    }

    for (_, path) in service.jobs.drain() {
        service.desktop.end_job(&path, None, true);
    }
    service.rqs.stop().await;
    Ok(())
}

fn visibility_for(mode: Mode) -> Visibility {
    match mode {
        Mode::Everyone => Visibility::Visible,
        Mode::Hidden => Visibility::Invisible,
    }
}

impl Service {
    fn transfer(&mut self, id: &str) -> Option<&mut Transfer> {
        self.transfers.iter_mut().find(|t| t.id == id)
    }

    fn effective_visibility(&self) -> &'static str {
        match (self.config.visibility, self.temporary_until) {
            (Mode::Everyone, _) => "everyone",
            (Mode::Hidden, Some(_)) => "temporary",
            (Mode::Hidden, None) => "hidden",
        }
    }

    fn apply_visibility(&mut self) {
        let visible = self.config.visibility == Mode::Everyone || self.temporary_until.is_some();
        self.rqs.change_visibility(if visible {
            Visibility::Visible
        } else {
            Visibility::Invisible
        });
        self.dirty = true;
    }

    fn flush(&mut self) {
        let now = Instant::now();
        let visible_for = self
            .temporary_until
            .map(|until| until.saturating_duration_since(now).as_secs())
            .unwrap_or(0);
        let folder = self
            .config
            .download_folder()
            .unwrap_or_else(rqs_lib::utils::get_download_dir);
        let state = json!({
            "visibility": self.effective_visibility(),
            "visibleFor": visible_for,
            "name": self.config.name,
            "folder": folder.to_string_lossy(),
            "askNearby": self.config.ask_nearby,
            "discovering": self.discovering_until.is_some(),
            "devices": self.devices.values().collect::<Vec<_>>(),
            "transfers": self.transfers,
        })
        .to_string();
        if let Ok(mut shared) = self.shared.lock() {
            *shared = state.clone();
        }
        bus::changed(&self.conn, &state);
        self.dirty = false;
    }

    async fn tick(&mut self) {
        let now = Instant::now();
        if let Some(until) = self.temporary_until {
            if now >= until {
                self.temporary_until = None;
                self.apply_visibility();
            } else {
                self.dirty = true;
            }
        }
        if let Some(until) = self.discovering_until {
            if now >= until {
                self.stop_discovery();
            }
        }
        let before = self.transfers.len();
        self.transfers.retain(|t| !t.stale(now));
        if before != self.transfers.len() {
            self.dirty = true;
        }
        if self.restart_pending && !self.transfers.iter().any(|t| !t.phase.is_over()) {
            self.restart().await;
        }
        if self.dirty {
            for transfer in &self.transfers {
                if transfer.phase == Phase::Transferring {
                    if let Some(path) = self.jobs.get(&transfer.id) {
                        let title = job_title(transfer);
                        self.desktop
                            .update_job(path, &title, &text::file_list(&transfer.files), transfer.done, transfer.total);
                    }
                }
            }
            self.flush();
        }
    }

    async fn restart(&mut self) {
        self.restart_pending = false;
        let discovering = self.discovering_until.is_some();
        self.rqs.stop().await;
        self.devices.clear();
        match self.rqs.run().await {
            Ok((send_tx, ble_rx)) => {
                self.send_tx = send_tx;
                self.ble_rx = ble_rx;
                self.apply_visibility();
                if discovering {
                    self.discovering_until = None;
                    self.start_discovery();
                }
            }
            Err(err) => error!("could not restart Quick Share: {err}"),
        }
        self.dirty = true;
    }

    fn start_discovery(&mut self) {
        if self.discovering_until.is_none() {
            if let Err(err) = self.rqs.discovery(self.device_tx.clone()) {
                warn!("could not look for devices: {err}");
                return;
            }
        }
        self.discovering_until = Some(Instant::now() + DISCOVERY);
        self.dirty = true;
    }

    fn stop_discovery(&mut self) {
        if self.discovering_until.take().is_some() {
            self.rqs.stop_discovery();
        }
        self.devices.clear();
        self.dirty = true;
    }

    fn device(&mut self, info: EndpointInfo) {
        if info.present == Some(false) {
            self.devices.remove(&info.id);
        } else if let Some(device) = state::device_from_endpoint(&info) {
            self.devices.insert(device.id.clone(), device);
        }
        self.dirty = true;
    }

    fn lib_action(&self, id: &str, action: TransferAction) {
        let _ = self.rqs.message_sender.send(ChannelMessage {
            id: id.to_string(),
            msg: Message::Lib { action },
        });
    }

    async fn command(&mut self, command: Command) {
        match command {
            Command::SetVisibility(mode) => {
                match mode.as_str() {
                    "everyone" => {
                        self.config.visibility = Mode::Everyone;
                        self.temporary_until = None;
                    }
                    "temporary" => {
                        self.config.visibility = Mode::Hidden;
                        self.temporary_until = Some(Instant::now() + TEMPORARY);
                    }
                    "hidden" => {
                        self.config.visibility = Mode::Hidden;
                        self.temporary_until = None;
                    }
                    other => {
                        warn!("unknown visibility {other}");
                        return;
                    }
                }
                self.config.save();
                self.apply_visibility();
            }
            Command::SetName(name) => {
                if let Some(name) = config::clean_name(&name) {
                    if name != self.config.name {
                        self.config.name = name.clone();
                        self.config.save();
                        self.rqs.set_device_name(name);
                        self.restart_pending = true;
                        self.dirty = true;
                    }
                }
            }
            Command::SetFolder(folder) => {
                let folder = bus::decode_path(&folder).unwrap_or_default();
                self.config.folder = folder;
                self.config.save();
                self.rqs.set_download_path(self.config.download_folder());
                self.dirty = true;
            }
            Command::SetAskNearby(enabled) => {
                self.config.ask_nearby = enabled;
                self.config.save();
                self.dirty = true;
            }
            Command::StartDiscovery => self.start_discovery(),
            Command::StopDiscovery => self.stop_discovery(),
            Command::Send(id, device, files) => self.send(id, device, files).await,
            Command::Accept(id) => self.answer(&id, true).await,
            Command::Decline(id) => self.answer(&id, false).await,
            Command::Cancel(id) => self.lib_action(&id, TransferAction::TransferCancel),
            Command::Dismiss(id) => {
                self.transfers.retain(|t| t.id != id || !t.phase.is_over());
                self.dirty = true;
            }
            Command::NotificationAction(note, action) => self.note_action(note, &action).await,
            Command::NotificationClosed(note, reason) => {
                if let Some(NoteKind::Consent(id)) = self.notes.remove(&note) {
                    let waiting = self
                        .transfers
                        .iter()
                        .any(|t| t.id == id && t.phase == Phase::Waiting && !t.outgoing);
                    if reason == 2 && waiting {
                        self.lib_action(&id, TransferAction::ConsentDecline);
                    }
                }
            }
            Command::JobCancelled(path) => {
                let id = self
                    .jobs
                    .iter()
                    .find(|(_, job)| **job == path)
                    .map(|(id, _)| id.clone());
                if let Some(id) = id {
                    self.lib_action(&id, TransferAction::TransferCancel);
                }
            }
        }
    }

    async fn send(&mut self, id: String, device: String, files: Vec<String>) {
        let Some(target) = self.devices.get(&device).cloned() else {
            warn!("unknown device {device}");
            return;
        };
        let transfer = Transfer::outgoing(&id, &target, &files);
        self.transfers.push(transfer);
        self.dirty = true;
        let info = SendInfo {
            id: id.clone(),
            name: target.name.clone(),
            addr: target.addr.clone(),
            ob: OutboundPayload::Files(files),
        };
        if let Err(err) = self.send_tx.send(info).await {
            error!("could not start sending: {err}");
            if let Some(t) = self.transfer(&id) {
                t.phase = Phase::Failed;
            }
        }
    }

    async fn answer(&mut self, id: &str, accept: bool) {
        let note = self
            .notes
            .iter()
            .find(|(_, kind)| matches!(kind, NoteKind::Consent(t) if t == id))
            .map(|(note, _)| *note);
        if let Some(note) = note {
            self.notes.remove(&note);
            self.desktop.close(note).await;
        }
        self.lib_action(
            id,
            if accept {
                TransferAction::ConsentAccept
            } else {
                TransferAction::ConsentDecline
            },
        );
    }

    async fn note_action(&mut self, note: u32, action: &str) {
        let Some(kind) = self.notes.get(&note) else {
            return;
        };
        match kind {
            NoteKind::Consent(id) => {
                let id = id.clone();
                match action {
                    "accept" => self.answer(&id, true).await,
                    "decline" => self.answer(&id, false).await,
                    _ => {}
                }
            }
            NoteKind::Nearby => {
                if action == "visible" || action == "default" {
                    self.notes.remove(&note);
                    self.desktop.close(note).await;
                    self.temporary_until = Some(Instant::now() + TEMPORARY);
                    self.apply_visibility();
                }
            }
            NoteKind::Received(id) => {
                let id = id.clone();
                let Some(transfer) = self.transfers.iter().find(|t| t.id == id).cloned() else {
                    return;
                };
                match (transfer.kind, action) {
                    ("files", "default") | ("files", "folder") => {
                        let folder = self
                            .config
                            .download_folder()
                            .unwrap_or_else(rqs_lib::utils::get_download_dir);
                        desktop::launch("xdg-open", &[&folder.to_string_lossy()]);
                    }
                    ("url", "open") | ("url", "default") if web_link(&transfer.text) => {
                        desktop::launch("xdg-open", &[&transfer.text]);
                    }
                    ("url", "copy") | ("text", "copy") | ("text", "default") => {
                        self.desktop.copy_text(&transfer.text).await;
                    }
                    ("wifi", "connect") => {
                        if let Some((ssid, password)) = &transfer.wifi {
                            if password.is_empty() {
                                desktop::launch("nmcli", &["device", "wifi", "connect", ssid]);
                            } else {
                                desktop::launch(
                                    "nmcli",
                                    &["device", "wifi", "connect", ssid, "password", password],
                                );
                            }
                        }
                    }
                    _ => {}
                }
            }
        }
    }

    async fn nearby(&mut self) {
        if self.config.visibility == Mode::Everyone
            || self.temporary_until.is_some()
            || !self.config.ask_nearby
        {
            return;
        }
        let now = Instant::now();
        if self
            .last_nearby
            .is_some_and(|last| now.duration_since(last) < NEARBY_PAUSE)
        {
            return;
        }
        if self.notes.values().any(|kind| matches!(kind, NoteKind::Nearby)) {
            return;
        }
        self.last_nearby = Some(now);
        let body = text::nearby_body(&self.config.name);
        let id = self
            .desktop
            .notify(
                0,
                Note {
                    summary: text::nearby_title(),
                    body: &body,
                    actions: &[("visible", text::make_visible())],
                    urgent: false,
                    urls: Vec::new(),
                    resident: false,
                },
            )
            .await;
        if id != 0 {
            self.notes.insert(id, NoteKind::Nearby);
        }
    }

    async fn message(&mut self, message: ChannelMessage) {
        let Message::Client(client) = &message.msg else {
            return;
        };
        let outgoing = client.kind == TransferKind::Outbound;
        let index = match self.transfers.iter().position(|t| t.id == message.id) {
            Some(index) => index,
            None if outgoing => match self
                .transfers
                .iter()
                .position(|t| t.outgoing && t.addr == message.id && !t.phase.is_over())
            {
                Some(index) => index,
                None => return,
            },
            None => {
                self.transfers.push(Transfer::incoming(&message.id));
                self.transfers.len() - 1
            }
        };
        let before = self.transfers[index].phase;
        let changed = self.transfers[index].apply(&message);
        if changed {
            self.dirty = true;
        }
        let transfer = self.transfers[index].clone();
        if transfer.phase != before {
            self.phase_changed(&transfer).await;
        }
    }

    async fn phase_changed(&mut self, transfer: &Transfer) {
        let device = if transfer.device.is_empty() {
            text::unknown_device()
        } else {
            transfer.device.clone()
        };
        match transfer.phase {
            Phase::Waiting if !transfer.outgoing && transfer.unsafe_names() => {
                warn!("declined {}: a file name points outside the download folder", transfer.id);
                self.lib_action(&transfer.id, TransferAction::ConsentDecline);
            }
            Phase::Waiting if !transfer.outgoing => {
                let mut body = match transfer.kind {
                    "files" => text::file_list(&transfer.files),
                    _ => transfer.preview.clone(),
                };
                if !transfer.pin.is_empty() {
                    if !body.is_empty() {
                        body.push('\n');
                    }
                    body.push_str(&text::pin(&transfer.pin));
                }
                let summary = text::wants_to_share(&device);
                let id = self
                    .desktop
                    .notify(
                        0,
                        Note {
                            summary: &summary,
                            body: &body,
                            actions: &[("accept", text::accept()), ("decline", text::decline())],
                            urgent: true,
                            urls: Vec::new(),
                            resident: true,
                        },
                    )
                    .await;
                if id != 0 {
                    self.notes.insert(id, NoteKind::Consent(transfer.id.clone()));
                }
            }
            Phase::Waiting => {
                let title = text::waiting_for(&device);
                if let Some(path) = self.desktop.open_job(&title, true).await {
                    self.jobs.insert(transfer.id.clone(), path);
                }
            }
            Phase::Transferring => {
                if transfer.kind == "files" && !self.jobs.contains_key(&transfer.id) {
                    if let Some(path) = self.desktop.open_job(&job_title(transfer), true).await {
                        self.jobs.insert(transfer.id.clone(), path);
                    }
                }
            }
            Phase::Finished => {
                self.close_consent(&transfer.id).await;
                if let Some(path) = self.jobs.remove(&transfer.id) {
                    self.desktop.end_job(&path, None, false);
                }
                if !transfer.outgoing {
                    self.received(transfer, &device).await;
                }
            }
            Phase::Rejected | Phase::Cancelled | Phase::Failed => {
                self.close_consent(&transfer.id).await;
                if let Some(path) = self.jobs.remove(&transfer.id) {
                    let (error, cancelled) = match transfer.phase {
                        Phase::Rejected => (None, true),
                        Phase::Cancelled => (Some(text::cancelled().to_string()), true),
                        _ => (Some(text::connection_lost().to_string()), false),
                    };
                    self.desktop.end_job(&path, error.as_deref(), cancelled);
                }
                if transfer.outgoing && transfer.phase == Phase::Rejected {
                    let summary = text::declined_by(&device);
                    let body = text::file_list(&transfer.files);
                    self.desktop
                        .notify(
                            0,
                            Note {
                                summary: &summary,
                                body: &body,
                                actions: &[],
                                urgent: false,
                                urls: Vec::new(),
                                resident: false,
                            },
                        )
                        .await;
                }
            }
            _ => {}
        }
        self.dirty = true;
    }

    async fn close_consent(&mut self, id: &str) {
        let note = self
            .notes
            .iter()
            .find(|(_, kind)| matches!(kind, NoteKind::Consent(t) if t == id))
            .map(|(note, _)| *note);
        if let Some(note) = note {
            self.notes.remove(&note);
            self.desktop.close(note).await;
        }
    }

    async fn received(&mut self, transfer: &Transfer, device: &str) {
        let folder = self
            .config
            .download_folder()
            .unwrap_or_else(rqs_lib::utils::get_download_dir);
        let (summary, body, actions, urls): (String, String, Vec<(&str, &str)>, Vec<String>) =
            match transfer.kind {
                "files" => (
                    text::received_from(device),
                    text::file_list(&transfer.files),
                    vec![("folder", text::open_folder())],
                    transfer
                        .files
                        .iter()
                        .map(|name| desktop::file_url(&latest_copy(&folder, name)))
                        .collect(),
                ),
                "url" => (
                    text::link_from(device),
                    transfer.text.clone(),
                    if web_link(&transfer.text) {
                        vec![("open", text::open()), ("copy", text::copy())]
                    } else {
                        vec![("copy", text::copy())]
                    },
                    Vec::new(),
                ),
                "wifi" => (
                    text::wifi_from(device),
                    transfer.preview.clone(),
                    vec![("connect", text::connect())],
                    Vec::new(),
                ),
                _ => (
                    text::text_from(device),
                    transfer.text.clone(),
                    vec![("copy", text::copy())],
                    Vec::new(),
                ),
            };
        let mut actions = actions;
        actions.insert(0, ("default", ""));
        let id = self
            .desktop
            .notify(
                0,
                Note {
                    summary: &summary,
                    body: &body,
                    actions: &actions,
                    urgent: false,
                    urls,
                    resident: false,
                },
            )
            .await;
        if id != 0 {
            self.notes.insert(id, NoteKind::Received(transfer.id.clone()));
        }
    }
}

fn job_title(transfer: &Transfer) -> String {
    let device = if transfer.device.is_empty() {
        text::unknown_device()
    } else {
        transfer.device.clone()
    };
    if transfer.outgoing {
        text::sending_to(&device)
    } else {
        text::receiving_from(&device)
    }
}

fn latest_copy(folder: &std::path::Path, name: &str) -> std::path::PathBuf {
    let original = folder.join(name);
    let path = std::path::Path::new(name);
    let stem = path.file_stem().map(|s| s.to_string_lossy().into_owned()).unwrap_or_default();
    let extension = path.extension().map(|e| format!(".{}", e.to_string_lossy())).unwrap_or_default();
    let modified = |p: &std::path::Path| p.metadata().and_then(|m| m.modified()).ok();
    let mut best = original.clone();
    let mut best_time = modified(&original);
    for counter in 1..1000 {
        let candidate = folder.join(format!("{stem} ({counter}){extension}"));
        let Some(time) = modified(&candidate) else {
            break;
        };
        if best_time.is_none_or(|current| time >= current) {
            best = candidate;
            best_time = Some(time);
        }
    }
    best
}

fn web_link(text: &str) -> bool {
    let lower = text.trim().to_ascii_lowercase();
    (lower.starts_with("https://") || lower.starts_with("http://"))
        && !text.chars().any(|c| c.is_whitespace() || c.is_control())
}
