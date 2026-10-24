// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-3.0-or-later

use std::collections::HashMap;
use std::process::{Command, Stdio};
use std::sync::Arc;
use std::time::Duration;

use dbus::arg::{PropMap, RefArg, Variant};
use dbus::channel::Sender;
use dbus::message::MatchRule;
use dbus::nonblock::{MsgMatch, Proxy, SyncConnection};
use dbus::{Message, Path};
use tokio::sync::mpsc::UnboundedSender;

use crate::Command as Event;

pub const DESKTOP_ENTRY: &str = "org.kernora.quickshare";
const ICON: &str = "kernora-quickshare";
const TIMEOUT: Duration = Duration::from_secs(4);

pub struct Desktop {
    conn: Arc<SyncConnection>,
    _matches: Vec<MsgMatch>,
}

pub struct Note<'a> {
    pub icon: &'a str,
    pub summary: &'a str,
    pub body: &'a str,
    pub actions: &'a [(&'a str, &'a str)],
    pub urgent: bool,
    pub urls: Vec<String>,
    pub resident: bool,
}

fn variant<T: RefArg + 'static>(value: T) -> Variant<Box<dyn RefArg>> {
    Variant(Box::new(value))
}

impl Desktop {
    pub async fn new(
        conn: Arc<SyncConnection>,
        events: UnboundedSender<Event>,
    ) -> Result<Self, anyhow::Error> {
        let mut matches = Vec::new();

        let tx = events.clone();
        let rule = MatchRule::new_signal("org.freedesktop.Notifications", "ActionInvoked");
        matches.push(conn.add_match(rule).await?.cb(move |_, (id, action): (u32, String)| {
            let _ = tx.send(Event::NotificationAction(id, action));
            true
        }));

        let tx = events.clone();
        let rule = MatchRule::new_signal("org.freedesktop.Notifications", "NotificationClosed");
        matches.push(conn.add_match(rule).await?.cb(move |_, (id, reason): (u32, u32)| {
            let _ = tx.send(Event::NotificationClosed(id, reason));
            true
        }));

        let tx = events;
        let rule = MatchRule::new_signal("org.kde.JobViewV3", "cancelRequested");
        matches.push(conn.add_match(rule).await?.cb(move |message: Message, (): ()| {
            if let Some(path) = message.path() {
                let _ = tx.send(Event::JobCancelled(path.to_string()));
            }
            true
        }));

        Ok(Self {
            conn,
            _matches: matches,
        })
    }

    fn notifications(&self) -> Proxy<'_, Arc<SyncConnection>> {
        Proxy::new(
            "org.freedesktop.Notifications",
            "/org/freedesktop/Notifications",
            TIMEOUT,
            self.conn.clone(),
        )
    }

    pub async fn notify(&self, replaces: u32, note: Note<'_>) -> u32 {
        let mut actions: Vec<&str> = Vec::new();
        for (key, label) in note.actions {
            actions.push(key);
            actions.push(label);
        }
        let mut hints: PropMap = HashMap::new();
        hints.insert("desktop-entry".into(), variant(DESKTOP_ENTRY.to_string()));
        hints.insert("urgency".into(), variant(if note.urgent { 2u8 } else { 1u8 }));
        if note.resident {
            hints.insert("resident".into(), variant(true));
        }
        if !note.urls.is_empty() {
            hints.insert("x-kde-urls".into(), variant(note.urls.clone()));
        }
        let timeout: i32 = if note.urgent { 0 } else { -1 };
        let result: Result<(u32,), dbus::Error> = self
            .notifications()
            .method_call(
                "org.freedesktop.Notifications",
                "Notify",
                (
                    crate::text::app_name(),
                    replaces,
                    if note.icon.is_empty() { ICON } else { note.icon },
                    note.summary,
                    note.body,
                    actions,
                    hints,
                    timeout,
                ),
            )
            .await;
        match result {
            Ok((id,)) => id,
            Err(err) => {
                warn!("could not show a notification: {err}");
                0
            }
        }
    }

    pub async fn close(&self, id: u32) {
        if id == 0 {
            return;
        }
        let result: Result<(), dbus::Error> = self
            .notifications()
            .method_call("org.freedesktop.Notifications", "CloseNotification", (id,))
            .await;
        if let Err(err) = result {
            debug!("could not close notification {id}: {err}");
        }
    }

    pub async fn open_job(&self, title: &str, cancellable: bool) -> Option<String> {
        let proxy = Proxy::new("org.kde.JobViewServer", "/JobViewServer", TIMEOUT, self.conn.clone());
        let mut hints: PropMap = HashMap::new();
        hints.insert("title".into(), variant(title.to_string()));
        let result: Result<(Path<'static>,), dbus::Error> = proxy
            .method_call(
                "org.kde.JobViewServerV2",
                "requestView",
                (DESKTOP_ENTRY, if cancellable { 1i32 } else { 0i32 }, hints),
            )
            .await;
        match result {
            Ok((path,)) => {
                let path = path.to_string();
                self.update_job(&path, title, "", 0, 0);
                Some(path)
            }
            Err(err) => {
                warn!("could not show the transfer progress: {err}");
                None
            }
        }
    }

    pub fn update_job(&self, path: &str, title: &str, info: &str, done: u64, total: u64) {
        let mut props: PropMap = HashMap::new();
        props.insert("title".into(), variant(title.to_string()));
        props.insert("infoMessage".into(), variant(info.to_string()));
        if total > 0 {
            let percent = ((done.min(total) as f64 / total as f64) * 100.0).round() as u32;
            props.insert("percent".into(), variant(percent));
            props.insert("processedBytes".into(), variant(done));
            props.insert("totalBytes".into(), variant(total));
        }
        self.job_call(path, "update", |message| message.append1(props));
    }

    pub fn end_job(&self, path: &str, error: Option<&str>, cancelled: bool) {
        let code: u32 = if cancelled {
            1
        } else if error.is_some() {
            2
        } else {
            0
        };
        let message = error.unwrap_or("").to_string();
        let hints: PropMap = HashMap::new();
        self.job_call(path, "terminate", |m| m.append3(code, message, hints));
    }

    fn job_call(&self, path: &str, method: &str, fill: impl FnOnce(Message) -> Message) {
        let Ok(object) = Path::new(path.to_string()) else {
            return;
        };
        match Message::new_method_call("org.kde.JobViewServer", object, "org.kde.JobViewV3", method) {
            Ok(message) => {
                let mut message = fill(message);
                message.set_no_reply(true);
                let _ = self.conn.send(message);
            }
            Err(err) => debug!("bad job call {method}: {err}"),
        }
    }

    pub async fn copy_text(&self, text: &str) {
        let proxy = Proxy::new("org.kde.klipper", "/klipper", TIMEOUT, self.conn.clone());
        let result: Result<(), dbus::Error> = proxy
            .method_call("org.kde.klipper.klipper", "setClipboardContents", (text,))
            .await;
        if let Err(err) = result {
            warn!("could not copy to the clipboard: {err}");
        }
    }
}

pub fn copy_image(path: &std::path::Path, mime: &str) {
    let Ok(file) = std::fs::File::open(path) else {
        warn!("could not open {} to copy it", path.display());
        return;
    };
    let result = Command::new("wl-copy")
        .args(["--type", mime])
        .stdin(Stdio::from(file))
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn();
    match result {
        Ok(mut child) => {
            std::thread::spawn(move || {
                let _ = child.wait();
            });
        }
        Err(err) => warn!("could not copy the image: {err}"),
    }
}

pub fn launch(program: &str, args: &[&str]) {
    let result = Command::new(program)
        .args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn();
    match result {
        Ok(mut child) => {
            std::thread::spawn(move || {
                let _ = child.wait();
            });
        }
        Err(err) => warn!("could not start {program}: {err}"),
    }
}

pub fn file_url(path: &std::path::Path) -> String {
    let mut url = String::from("file://");
    for byte in path.to_string_lossy().as_bytes() {
        match byte {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'/' | b'-' | b'_' | b'.' | b'~' => {
                url.push(*byte as char)
            }
            other => url.push_str(&format!("%{other:02X}")),
        }
    }
    url
}
