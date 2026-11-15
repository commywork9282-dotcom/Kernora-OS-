/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

.pragma library

var prefix = "org.kernora.widget.";

var apps = [
    { id: "battery", icon: "org.kernora.battery", plugins: ["org.kernora.widget.battery"] },
    { id: "calendar", icon: "org.kernora.calendar", plugins: ["org.kernora.widget.calendar"] },
    { id: "clock", icon: "org.kernora.clock", plugins: ["org.kernora.widget.clock"] },
    { id: "kernora", icon: "kernora-logo", plugins: ["org.kernora.widget.glance"] },
    { id: "player", icon: "org.kernora.player", plugins: ["org.kernora.widget.media"] },
    { id: "notes", icon: "org.kernora.notes", plugins: ["org.kernora.widget.note"] },
    { id: "photos", icon: "org.kernora.photos", plugins: ["org.kernora.widget.photo"] },
    { id: "taskmanager", icon: "org.kernora.taskmanager", plugins: ["org.kernora.widget.cputemperature"] },
    { id: "weather", icon: "org.kernora.weather", plugins: ["org.kernora.widget.weather"] }
];

var suggestions = [
    { id: "essentials", plugins: ["org.kernora.widget.clock", "org.kernora.widget.weather", "org.kernora.widget.glance",
                                  "org.kernora.widget.calendar", "org.kernora.widget.battery"] },
    { id: "others", plugins: ["org.kernora.widget.media", "org.kernora.widget.note", "org.kernora.widget.photo"] }
];

var spans = {
    "org.kernora.widget.battery": [2, 2],
    "org.kernora.widget.calendar": [3, 3],
    "org.kernora.widget.clock": [2, 2],
    "org.kernora.widget.cputemperature": [2, 3],
    "org.kernora.widget.glance": [4, 1],
    "org.kernora.widget.media": [3, 2],
    "org.kernora.widget.note": [2, 2],
    "org.kernora.widget.photo": [2, 2],
    "org.kernora.widget.weather": [2, 2]
};

function span(pluginName) {
    return spans[pluginName] || [2, 2];
}

function kind(pluginName) {
    return String(pluginName).indexOf(prefix) === 0 ? String(pluginName).substring(prefix.length) : "";
}
