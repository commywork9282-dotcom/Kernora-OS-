/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: LGPL-2.0-or-later
*/

.pragma library

var kernoraPrefix = "org.kernora.widget.";

var groups = ["time", "monitor", "files", "media", "system", "input", "panel"];
var panelGroups = ["panel", "system", "time", "media", "input", "monitor", "files"];

var widgets = {
    "org.kernora.widget.clock": { icon: "clock" },
    "org.kernora.widget.glance": { icon: "weather-few-clouds" },
    "org.kernora.widget.weather": { icon: "weather-few-clouds" },
    "org.kernora.widget.calendar": { icon: "view-calendar" },
    "org.kernora.widget.battery": { icon: "battery-full" },
    "org.kernora.widget.media": { icon: "media-playback-start" },
    "org.kernora.widget.photo": { icon: "image-x-generic" },
    "org.kernora.widget.note": { icon: "note" },

    "org.kde.plasma.analogclock": { group: "time", icon: "kernora-analog-clock", preview: "analog" },
    "org.kde.plasma.digitalclock": { group: "time", icon: "kernora-digital-clock", preview: "digital" },
    "org.kde.plasma.calendar": { group: "time", icon: "office-calendar", preview: "month" },

    "org.kde.plasma.systemmonitor.cpu": { group: "monitor", icon: "cpu", preview: "chart", badge: "cpu",
                                          value: "23%", lines: [[0.3, 0.42, 0.35, 0.6, 0.48, 0.7, 0.52, 0.4, 0.55, 0.38, 0.46]] },
    "org.kde.plasma.systemmonitor.cpucore": { group: "monitor", icon: "kernora-bar-chart", preview: "cores" },
    "org.kde.plasma.systemmonitor.memory": { group: "monitor", icon: "kernora-memory", preview: "chart", badge: "kernora-memory",
                                             value: "62%", lines: [[0.5, 0.52, 0.55, 0.55, 0.58, 0.6, 0.6, 0.61, 0.6, 0.62, 0.62]] },
    "org.kde.plasma.systemmonitor.diskusage": { group: "monitor", icon: "kernora-partition", preview: "donut", fraction: 0.64 },
    "org.kde.plasma.systemmonitor.diskactivity": { group: "monitor", icon: "drive-harddisk", preview: "chart", badge: "drive-harddisk",
                                                   lines: [[0.1, 0.5, 0.2, 0.15, 0.7, 0.3, 0.1, 0.4, 0.2, 0.1, 0.3],
                                                           [0.05, 0.1, 0.3, 0.1, 0.2, 0.45, 0.15, 0.1, 0.25, 0.05, 0.1]] },
    "org.kde.plasma.systemmonitor.net": { group: "monitor", icon: "network-transmit-receive", preview: "chart", badge: "network-transmit-receive",
                                          lines: [[0.2, 0.35, 0.6, 0.5, 0.75, 0.55, 0.4, 0.65, 0.5, 0.45, 0.6],
                                                  [0.1, 0.12, 0.2, 0.15, 0.25, 0.18, 0.12, 0.2, 0.16, 0.1, 0.14]] },
    "org.kde.plasma.systemmonitor": { group: "monitor", icon: "ksysguardd", preview: "sensor" },

    "org.kde.plasma.folder": { group: "files", icon: "folder", preview: "folder" },
    "org.kde.plasma.trash": { group: "files", icon: "user-trash", preview: "glyph", shape: "cookie9", tone: "secondary" },
    "org.kde.plasma.vault": { group: "files", icon: "plasmavault", preview: "glyph", shape: "gem", tone: "tertiary" },
    "org.kde.plasma.devicenotifier": { group: "files", icon: "drive-removable-media-usb", preview: "rows",
                                       rows: [{ icon: "drive-removable-media-usb", trailing: "media-eject", active: true },
                                              { icon: "drive-harddisk", trailing: "media-eject" }] },

    "org.kde.plasma.mediacontroller": { group: "media", icon: "audio-x-generic", preview: "player" },
    "org.kde.plasma.volume": { group: "media", icon: "audio-volume-high", preview: "sliders",
                               sliders: [{ icon: "audio-volume-high", value: 0.7 }, { icon: "audio-input-microphone", value: 0.45 }] },

    "org.kde.plasma.networkmanagement": { group: "system", icon: "network-wireless", preview: "rows",
                                          rows: [{ icon: "network-wireless", active: true },
                                                 { icon: "network-wireless-signal-good" },
                                                 { icon: "network-wireless-signal-ok" }] },
    "org.kde.plasma.bluetooth": { group: "system", icon: "bluetooth", preview: "rows",
                                  rows: [{ icon: "audio-headphones", active: true }, { icon: "input-mouse" }, { icon: "phone" }] },
    "org.kde.plasma.battery": { group: "system", icon: "battery-full", preview: "battery", fraction: 0.8 },
    "org.kde.plasma.brightness": { group: "system", icon: "brightness-high", preview: "sliders",
                                   sliders: [{ icon: "brightness-high", value: 0.6 }] },
    "org.kde.kscreen": { group: "system", icon: "preferences-desktop-display-randr", preview: "screens" },
    "org.kde.plasma.lock_logout": { group: "system", icon: "system-shutdown", preview: "buttons",
                                    buttons: ["system-lock-screen", "system-shutdown"] },
    "org.kde.plasma.notifications": { group: "system", icon: "preferences-desktop-notification-bell", preview: "rows", tall: true,
                                      rows: [{ icon: "mail-unread", active: true }, { icon: "notification-active" }] },
    "org.kde.plasma.clipboard": { group: "system", icon: "edit-paste", preview: "rows",
                                  rows: [{ icon: "edit-paste", active: true }, { icon: "text-x-generic" }, { icon: "image-x-generic" }] },
    "org.kde.milou": { group: "system", icon: "system-search", preview: "search" },
    "org.kde.plasma.cameraindicator": { group: "system", icon: "camera-on", preview: "glyph", shape: "cookie4", tone: "tertiary" },

    "org.kde.plasma.keyboardlayout": { group: "input", icon: "input-keyboard", preview: "layout" },
    "org.kde.plasma.kimpanel": { group: "input", icon: "preferences-desktop-locale", preview: "glyph", shape: "clover4", tone: "secondary" },
    "org.kde.plasma.manage-inputmethod": { group: "input", icon: "input-keyboard-virtual", preview: "glyph", shape: "pill", tone: "primary" },

    "org.kernora.launcher": { group: "panel", icon: "start-here-kde-symbolic", preview: "panel", content: "launcher" },
    "org.kernora.quicksettings": { group: "panel", icon: "preferences-desktop", preview: "panel", content: "status" },
    "org.kernora.clipboard": { group: "panel", icon: "edit-paste", preview: "rows",
                               rows: [{ icon: "edit-paste", active: true }, { icon: "text-x-generic" }, { icon: "image-x-generic" }] },
    "org.kde.plasma.kickoff": { group: "panel", icon: "applications-all", preview: "panel", content: "launcher" },
    "org.kde.plasma.kicker": { group: "panel", icon: "applications-all", preview: "panel", content: "launcher" },
    "org.kde.plasma.icontasks": { group: "panel", icon: "kernora-dock", preview: "panel", content: "dock" },
    "org.kde.plasma.taskmanager": { group: "panel", icon: "kernora-dock", preview: "panel", content: "chips" },
    "org.kde.plasma.windowlist": { group: "panel", icon: "window", preview: "rows",
                                   rows: [{ icon: "window", active: true }, { icon: "window" }, { icon: "window" }] },
    "org.kde.plasma.systemtray": { group: "panel", icon: "preferences-desktop", preview: "panel", content: "tray" },
    "org.kde.plasma.pager": { group: "panel", icon: "org.kde.plasma.pager", preview: "panel", content: "pager" },
    "org.kde.plasma.activitypager": { group: "panel", icon: "activities", preview: "panel", content: "pager" },
    "org.kde.plasma.activitybar": { group: "panel", icon: "preferences-system-tabbox", preview: "panel", content: "tabs" },
    "org.kde.plasma.showActivityManager": { group: "panel", icon: "activities", preview: "panel", content: "button", glyph: "activities" },
    "org.kde.plasma.appmenu": { group: "panel", icon: "kernora-menu", preview: "panel", content: "menu" },
    "org.kde.plasma.showdesktop": { group: "panel", icon: "user-desktop", preview: "panel", content: "button", glyph: "user-desktop" },
    "org.kde.plasma.minimizeall": { group: "panel", icon: "window-minimize", preview: "panel", content: "button", glyph: "window-minimize" },
    "org.kde.plasma.panelspacer": { group: "panel", icon: "distribute-horizontal-x", preview: "panel", content: "spacer" },
    "org.kde.plasma.marginsseparator": { group: "panel", icon: "filename-divider", preview: "panel", content: "separator" }
};

function find(plugin) {
    return widgets[plugin] || null;
}

function rank(plugin, forPanel) {
    const order = forPanel ? panelGroups : groups;
    const entry = widgets[plugin];
    const position = entry && entry.group ? order.indexOf(entry.group) : -1;
    return position < 0 ? order.length : position;
}
