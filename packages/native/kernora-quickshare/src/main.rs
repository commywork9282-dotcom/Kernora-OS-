// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-3.0-or-later

#[macro_use]
extern crate log;

mod bus;
mod config;
mod desktop;
mod nearby;
mod state;
mod text;

use std::collections::{BTreeMap, HashMap, HashSet};
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
use nearby::Nearby;
use state::{Device, Phase, Transfer};
use text::Items;

const TEMPORARY: Duration = Duration::from_secs(600);
const DISCOVERY: Duration = Duration::from_secs(90);
const FLUSH: Duration = Duration::from_millis(250);
const CONNECTING: Duration = Duration::from_secs(25);

#[derive(Debug)]
pub enum Command {
    SetEnabled(bool),
    SetHighVisibility(bool),
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
    running: bool,
    cancelled_here: HashSet<String>,
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
    nearby: Nearby,
    nearby_listening: bool,
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
        running: true,
        cancelled_here: HashSet::new(),
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
        nearby: Nearby::default(),
        nearby_listening: false,
        restart_pending: false,
        dirty: true,
        desktop,
        conn: conn.clone(),
        shared: shared.clone(),
    };
    if service.config.enabled {
        service.sync_nearby_listener();
    } else {
        service.rqs.stop().await;
        service.running = false;
    }
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
            nearby = service.ble_rx.recv(), if service.running => {
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
        self.sync_nearby_listener();
        self.dirty = true;
    }

    fn sync_nearby_listener(&mut self) {
        let wanted = self.running && self.config.ask_nearby && self.effective_visibility() == "hidden";
        if wanted != self.nearby_listening {
            self.rqs.set_nearby_listener(wanted);
            self.nearby_listening = wanted;
        }
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
            "enabled": self.config.enabled,
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

    async fn close_nearby(&mut self) {
        let shown: Vec<u32> = self
            .notes
            .iter()
            .filter(|(_, kind)| matches!(kind, NoteKind::Nearby))
            .map(|(id, _)| *id)
            .collect();
        for id in shown {
            self.notes.remove(&id);
            self.desktop.close(id).await;
        }
    }

    async fn tick(&mut self) {
        let now = Instant::now();
        let pointless = self.nearby.lost(now)
            || !self.running
            || !self.config.ask_nearby
            || self.effective_visibility() != "hidden";
        if pointless && self.notes.values().any(|kind| matches!(kind, NoteKind::Nearby)) {
            self.close_nearby().await;
        }
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
        let stuck: Vec<Transfer> = self
            .transfers
            .iter_mut()
            .filter(|t| {
                t.outgoing
                    && t.phase == Phase::Connecting
                    && t.updated.is_some_and(|time| now.duration_since(time) > CONNECTING)
            })
            .map(|t| {
                t.phase = Phase::Failed;
                t.clone()
            })
            .collect();
        for transfer in stuck {
            warn!("could not reach {} in time", transfer.device);
            self.phase_changed(&transfer).await;
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
                        self.desktop
                            .update_job(path, &job_title(transfer), "", transfer.done, transfer.total);
                    }
                }
            }
            self.flush();
        }
    }

    async fn set_enabled(&mut self, enabled: bool) {
        if enabled == self.config.enabled && enabled == self.running {
            return;
        }
        self.config.enabled = enabled;
        self.config.save();
        if enabled {
            match self.rqs.run().await {
                Ok((send_tx, ble_rx)) => {
                    self.send_tx = send_tx;
                    self.ble_rx = ble_rx;
                    self.running = true;
                    self.apply_visibility();
                }
                Err(err) => error!("could not start Quick Share: {err}"),
            }
        } else {
            self.temporary_until = None;
            self.stop_discovery();
            self.rqs.stop().await;
            self.nearby_listening = false;
            self.running = false;
        }
        self.dirty = true;
    }

    async fn restart(&mut self) {
        self.restart_pending = false;
        if !self.running {
            return;
        }
        let discovering = self.discovering_until.is_some();
        self.rqs.stop().await;
        self.nearby_listening = false;
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
        if !self.running {
            return;
        }
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
            Command::SetEnabled(enabled) => self.set_enabled(enabled).await,
            Command::SetHighVisibility(on) => {
                if on && !self.running {
                    self.set_enabled(true).await;
                }
                self.temporary_until = on.then(|| Instant::now() + TEMPORARY);
                self.apply_visibility();
            }
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
                self.sync_nearby_listener();
                self.dirty = true;
            }
            Command::StartDiscovery => self.start_discovery(),
            Command::StopDiscovery => self.stop_discovery(),
            Command::Send(id, device, files) => self.send(id, device, files).await,
            Command::Accept(id) => self.answer(&id, true).await,
            Command::Decline(id) => self.answer(&id, false).await,
            Command::Cancel(id) => {
                self.cancelled_here.insert(id.clone());
                self.lib_action(&id, TransferAction::TransferCancel);
            }
            Command::Dismiss(id) => {
                self.transfers.retain(|t| t.id != id || !t.phase.is_over());
                self.dirty = true;
            }
            Command::NotificationAction(note, action) => self.note_action(note, &action).await,
            Command::NotificationClosed(note, reason) => match self.notes.remove(&note) {
                Some(NoteKind::Consent(id)) => {
                    let waiting = self
                        .transfers
                        .iter()
                        .any(|t| t.id == id && t.phase == Phase::Waiting && !t.outgoing);
                    if reason == 2 && waiting {
                        self.lib_action(&id, TransferAction::ConsentDecline);
                    }
                }
                Some(NoteKind::Nearby) if reason == 2 => self.nearby.snooze(Instant::now()),
                _ => {}
            },
            Command::JobCancelled(path) => {
                let id = self
                    .jobs
                    .iter()
                    .find(|(_, job)| **job == path)
                    .map(|(id, _)| id.clone());
                if let Some(id) = id {
                    self.cancelled_here.insert(id.clone());
                    self.lib_action(&id, TransferAction::TransferCancel);
                }
            }
        }
    }

    async fn send(&mut self, id: String, device: String, files: Vec<String>) {
        if !self.running {
            warn!("Quick Share is off, not sending");
            return;
        }
        let Some(target) = self.devices.get(&device).cloned() else {
            warn!("unknown device {device}");
            let gone = Device {
                id: device.clone(),
                name: device,
                kind: "unknown",
                addr: String::new(),
            };
            let mut transfer = Transfer::outgoing(&id, &gone, &files);
            transfer.phase = Phase::Failed;
            self.transfers.push(transfer);
            self.dirty = true;
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
                self.notes.remove(&note);
                self.desktop.close(note).await;
                match action {
                    "visible" | "default" => {
                        self.temporary_until = Some(Instant::now() + TEMPORARY);
                        self.apply_visibility();
                    }
                    "never" => {
                        self.config.ask_nearby = false;
                        self.config.save();
                        self.sync_nearby_listener();
                        self.dirty = true;
                    }
                    _ => self.nearby.snooze(Instant::now()),
                }
            }
            NoteKind::Received(id) => {
                let id = id.clone();
                let Some(transfer) = self.transfers.iter().find(|t| t.id == id).cloned() else {
                    return;
                };
                let folder = self
                    .config
                    .download_folder()
                    .unwrap_or_else(rqs_lib::utils::get_download_dir);
                match (transfer.kind, action) {
                    ("files", "default") | ("files", "folder") => {
                        desktop::launch("xdg-open", &[&folder.to_string_lossy()]);
                    }
                    ("files", "copy") => {
                        if let Some(name) = transfer.files.first() {
                            if let Some(mime) = text::image_mime(name) {
                                desktop::copy_image(&latest_copy(&folder, name), mime);
                            }
                        }
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
        let now = Instant::now();
        if !self.nearby.seen(now)
            || !self.running
            || self.config.visibility == Mode::Everyone
            || self.temporary_until.is_some()
            || !self.config.ask_nearby
            || self.nearby.snoozed(now)
            || self.notes.values().any(|kind| matches!(kind, NoteKind::Nearby))
        {
            return;
        }
        let id = self
            .desktop
            .notify(
                0,
                Note {
                    icon: "",
                    summary: text::nearby_title(),
                    body: text::nearby_body(),
                    actions: &[
                        ("visible", text::enable()),
                        ("dismiss", text::dismiss()),
                        ("never", text::never()),
                    ],
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
        let items = Items::of(transfer);
        match transfer.phase {
            Phase::Waiting if !transfer.outgoing && transfer.unsafe_names() => {
                warn!("declined {}: a file name points outside the download folder", transfer.id);
                self.lib_action(&transfer.id, TransferAction::ConsentDecline);
            }
            Phase::Waiting if !transfer.outgoing => {
                let mut body = if transfer.kind == "wifi" {
                    text::request_wifi(&device)
                } else {
                    text::request_body(&device, &items)
                };
                if !transfer.pin.is_empty() {
                    body.push('\n');
                    body.push_str(&text::connection_id(&transfer.pin));
                }
                let id = self
                    .desktop
                    .notify(
                        0,
                        Note {
                            icon: device_icon(transfer.device_kind),
                            summary: text::request_title(),
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
                if let Some(path) = self.desktop.open_job(&job_title(transfer), true).await {
                    self.desktop.update_job(&path, &job_title(transfer), &text::waiting(&device), 0, 0);
                    self.jobs.insert(transfer.id.clone(), path);
                }
            }
            Phase::Transferring => {
                if !self.jobs.contains_key(&transfer.id) {
                    if let Some(path) = self.desktop.open_job(&job_title(transfer), true).await {
                        self.jobs.insert(transfer.id.clone(), path);
                    }
                }
            }
            Phase::Finished => {
                self.close_consent(&transfer.id).await;
                if let Some(path) = self.jobs.remove(&transfer.id) {
                    self.desktop.end_job(&path, None, true);
                }
                if transfer.outgoing {
                    let summary = text::sent(&items, &device);
                    self.notify_plain(&summary, "").await;
                } else {
                    self.received(transfer, &device).await;
                }
            }
            Phase::Rejected | Phase::Cancelled | Phase::Failed => {
                self.close_consent(&transfer.id).await;
                if let Some(path) = self.jobs.remove(&transfer.id) {
                    self.desktop.end_job(&path, None, true);
                }
                let here = self.cancelled_here.remove(&transfer.id);
                let reached = transfer.outgoing || transfer.done > 0 || transfer.phase != Phase::Rejected;
                if transfer.outgoing && transfer.phase == Phase::Failed && transfer.done == 0 {
                    self.devices.retain(|_, d| d.addr != transfer.addr);
                }
                let shown_in_window = transfer.outgoing
                    && transfer.done == 0
                    && self.discovering_until.is_some();
                if !here && reached && !shown_in_window {
                    let summary = if transfer.outgoing {
                        text::send_failed(&items, &device)
                    } else {
                        text::receive_failed(&items, &device)
                    };
                    let body = match transfer.phase {
                        Phase::Rejected if transfer.outgoing => text::did_not_accept().to_string(),
                        Phase::Cancelled => text::sender_cancelled(&device),
                        _ => text::something_wrong().to_string(),
                    };
                    self.notify_plain(&summary, &body).await;
                }
            }
            _ => {}
        }
        self.dirty = true;
    }

    async fn notify_plain(&mut self, summary: &str, body: &str) {
        self.desktop
            .notify(
                0,
                Note {
                    icon: "",
                    summary,
                    body,
                    actions: &[],
                    urgent: false,
                    urls: Vec::new(),
                    resident: false,
                },
            )
            .await;
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
        let items = Items::of(transfer);
        let single_image = transfer.kind == "files"
            && transfer.files.len() == 1
            && text::image_mime(&transfer.files[0]).is_some();
        let (summary, body, actions, urls): (String, String, Vec<(&str, &str)>, Vec<String>) =
            match transfer.kind {
                "files" => (
                    text::received(&items, device),
                    if transfer.files.len() == 1 { transfer.files[0].clone() } else { String::new() },
                    if single_image {
                        vec![("folder", text::open_folder()), ("copy", text::copy())]
                    } else {
                        vec![("folder", text::open_folder())]
                    },
                    transfer
                        .files
                        .iter()
                        .map(|name| desktop::file_url(&latest_copy(&folder, name)))
                        .collect(),
                ),
                "url" => (
                    text::received(&items, device),
                    transfer.text.clone(),
                    if web_link(&transfer.text) {
                        vec![("open", text::open()), ("copy", text::copy())]
                    } else {
                        vec![("copy", text::copy())]
                    },
                    Vec::new(),
                ),
                "wifi" => (
                    text::wifi_received(&transfer.preview, device),
                    String::new(),
                    vec![("connect", text::connect())],
                    Vec::new(),
                ),
                _ => (
                    text::received(&items, device),
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
                    icon: "",
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

fn device_icon(kind: &str) -> &'static str {
    match kind {
        "phone" | "tablet" => "phone",
        "computer" => "computer",
        _ => "",
    }
}

fn job_title(transfer: &Transfer) -> String {
    let device = if transfer.device.is_empty() {
        text::unknown_device()
    } else {
        transfer.device.clone()
    };
    let items = Items::of(transfer);
    if transfer.outgoing {
        text::sending(&items, &device)
    } else if transfer.kind == "wifi" {
        text::receiving_wifi().to_string()
    } else {
        text::receiving(&items, &device)
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
