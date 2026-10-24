// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-3.0-or-later

use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex};

use dbus::channel::{MatchingReceiver, Sender};
use dbus::message::MatchRule;
use dbus::nonblock::SyncConnection;
use dbus::Message;
use dbus_crossroads::Crossroads;
use tokio::sync::mpsc::UnboundedSender;

use crate::Command;

pub const NAME: &str = "org.kernora.QuickShare";
pub const PATH: &str = "/org/kernora/QuickShare";
pub const INTERFACE: &str = "org.kernora.QuickShare1";

struct Bus {
    state: Arc<Mutex<String>>,
    commands: UnboundedSender<Command>,
    counter: Arc<AtomicU64>,
}

impl Bus {
    fn send(&self, command: Command) {
        let _ = self.commands.send(command);
    }
}

pub fn decode_path(input: &str) -> Option<String> {
    let raw = input.strip_prefix("file://").unwrap_or(input);
    let bytes = raw.as_bytes();
    let mut out = Vec::with_capacity(bytes.len());
    let mut index = 0;
    while index < bytes.len() {
        if bytes[index] == b'%' && index + 2 < bytes.len() {
            let hex = std::str::from_utf8(&bytes[index + 1..index + 3]).ok()?;
            out.push(u8::from_str_radix(hex, 16).ok()?);
            index += 3;
        } else {
            out.push(bytes[index]);
            index += 1;
        }
    }
    let path = String::from_utf8(out).ok()?;
    std::path::Path::new(&path).is_absolute().then_some(path)
}

pub fn serve(
    conn: &Arc<SyncConnection>,
    state: Arc<Mutex<String>>,
    commands: UnboundedSender<Command>,
) {
    let mut cr = Crossroads::new();
    let token = cr.register(INTERFACE, |b| {
        b.signal::<(String,), _>("Changed", ("state",));
        b.method("State", (), ("state",), |_, bus: &mut Bus, (): ()| {
            Ok((bus.state.lock().map(|s| s.clone()).unwrap_or_default(),))
        });
        b.method("SetEnabled", ("enabled",), (), |_, bus: &mut Bus, (enabled,): (bool,)| {
            bus.send(Command::SetEnabled(enabled));
            Ok(())
        });
        b.method("SetHighVisibility", ("on",), (), |_, bus: &mut Bus, (on,): (bool,)| {
            bus.send(Command::SetHighVisibility(on));
            Ok(())
        });
        b.method("SetVisibility", ("mode",), (), |_, bus: &mut Bus, (mode,): (String,)| {
            bus.send(Command::SetVisibility(mode));
            Ok(())
        });
        b.method("SetDeviceName", ("name",), (), |_, bus: &mut Bus, (name,): (String,)| {
            bus.send(Command::SetName(name));
            Ok(())
        });
        b.method("SetDownloadFolder", ("folder",), (), |_, bus: &mut Bus, (folder,): (String,)| {
            bus.send(Command::SetFolder(folder));
            Ok(())
        });
        b.method("SetAskNearby", ("enabled",), (), |_, bus: &mut Bus, (enabled,): (bool,)| {
            bus.send(Command::SetAskNearby(enabled));
            Ok(())
        });
        b.method("StartDiscovery", (), (), |_, bus: &mut Bus, (): ()| {
            bus.send(Command::StartDiscovery);
            Ok(())
        });
        b.method("StopDiscovery", (), (), |_, bus: &mut Bus, (): ()| {
            bus.send(Command::StopDiscovery);
            Ok(())
        });
        b.method(
            "Send",
            ("device", "files"),
            ("transfer",),
            |_, bus: &mut Bus, (device, files): (String, Vec<String>)| {
                let files: Vec<String> = files.iter().filter_map(|f| decode_path(f)).collect();
                if files.is_empty() {
                    return Err(dbus::MethodErr::invalid_arg("files"));
                }
                let id = format!("send-{}", bus.counter.fetch_add(1, Ordering::Relaxed));
                bus.send(Command::Send(id.clone(), device, files));
                Ok((id,))
            },
        );
        b.method("Accept", ("transfer",), (), |_, bus: &mut Bus, (id,): (String,)| {
            bus.send(Command::Accept(id));
            Ok(())
        });
        b.method("Decline", ("transfer",), (), |_, bus: &mut Bus, (id,): (String,)| {
            bus.send(Command::Decline(id));
            Ok(())
        });
        b.method("Cancel", ("transfer",), (), |_, bus: &mut Bus, (id,): (String,)| {
            bus.send(Command::Cancel(id));
            Ok(())
        });
        b.method("Dismiss", ("transfer",), (), |_, bus: &mut Bus, (id,): (String,)| {
            bus.send(Command::Dismiss(id));
            Ok(())
        });
    });
    cr.insert(
        PATH,
        &[token],
        Bus {
            state,
            commands,
            counter: Arc::new(AtomicU64::new(1)),
        },
    );
    let cr = Mutex::new(cr);
    conn.start_receive(
        MatchRule::new_method_call(),
        Box::new(move |message, conn| {
            if let Ok(mut cr) = cr.lock() {
                let _ = cr.handle_message(message, conn);
            }
            true
        }),
    );
}

pub fn changed(conn: &SyncConnection, state: &str) {
    let message = Message::signal(&PATH.into(), &INTERFACE.into(), &"Changed".into())
        .append1(state.to_string());
    let _ = conn.send(message);
}
