/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

.pragma library

var prefix = "org.kernora.widget.";

var apps = [
    { id: "battery", icon: "org.kernora.battery", plugins: ["org.kernora.widget.battery"] },
    { id: "calendar", icon: "org.kernora.calendar", plugins: ["org.kernora.widget.calendar"] },
    { id: "clock", icon: "org.kernora.clock", plugins: ["org.kernora.widget.clock#analog", "org.kernora.widget.clock#digital",
                                                       "org.kernora.widget.clock#stacked", "org.kernora.widget.worldclock"] },
    { id: "kernora", icon: "kernora-logo", plugins: ["org.kernora.widget.glance"] },
    { id: "player", icon: "org.kernora.player", plugins: ["org.kernora.widget.media"] },
    { id: "notes", icon: "org.kernora.notes", plugins: ["org.kernora.widget.note"] },
    { id: "photos", icon: "org.kernora.photos", plugins: ["org.kernora.widget.photo"] },
    { id: "taskmanager", icon: "org.kernora.taskmanager", plugins: ["org.kernora.widget.cputemperature"] },
    { id: "weather", icon: "org.kernora.weather", plugins: ["org.kernora.widget.weather#current",
                                                           "org.kernora.widget.weather#forecast"] }
];

var suggestions = [
    { id: "essentials", plugins: ["org.kernora.widget.clock#analog", "org.kernora.widget.weather#current", "org.kernora.widget.glance",
                                  "org.kernora.widget.calendar", "org.kernora.widget.battery"] },
    { id: "others", plugins: ["org.kernora.widget.media", "org.kernora.widget.note", "org.kernora.widget.photo"] }
];

var reconfigurable = ["org.kernora.widget.cputemperature", "org.kernora.widget.glance", "org.kernora.widget.photo",
                      "org.kernora.widget.weather", "org.kernora.widget.worldclock"];

var minimumSpans = {
    "org.kernora.widget.battery": [2, 2],
    "org.kernora.widget.calendar": [2, 3],
    "org.kernora.widget.cputemperature": [2, 3],
    "org.kernora.widget.glance": [2, 1],
    "org.kernora.widget.media": [2, 2],
    "org.kernora.widget.note": [2, 2],
    "org.kernora.widget.photo": [1, 2],
    "org.kernora.widget.weather": [2, 2]
};

function minimumSpan(entry) {
    return minimumSpans[plugin(entry)] || [1, 1];
}

var spans = {
    "org.kernora.widget.battery": [2, 2],
    "org.kernora.widget.calendar": [3, 3],
    "org.kernora.widget.clock": [2, 3],
    "org.kernora.widget.clock#analog": [2, 3],
    "org.kernora.widget.clock#digital": [2, 2],
    "org.kernora.widget.clock#stacked": [2, 3],
    "org.kernora.widget.cputemperature": [2, 3],
    "org.kernora.widget.glance": [4, 1],
    "org.kernora.widget.media": [3, 2],
    "org.kernora.widget.note": [2, 2],
    "org.kernora.widget.photo": [2, 2],
    "org.kernora.widget.weather": [2, 3],
    "org.kernora.widget.weather#current": [2, 3],
    "org.kernora.widget.weather#forecast": [3, 3],
    "org.kernora.widget.worldclock": [2, 2]
};

function plugin(entry) {
    return String(entry).split("#")[0];
}

function variant(entry) {
    var parts = String(entry).split("#");
    return parts.length > 1 ? parts[1] : "";
}

function config(entry) {
    var style = variant(entry);
    return style.length > 0 ? { style: style } : {};
}

function span(entry) {
    return spans[entry] || spans[plugin(entry)] || [2, 2];
}

function kind(entry) {
    var name = plugin(entry);
    var base = name.indexOf(prefix) === 0 ? name.substring(prefix.length) : "";
    var style = variant(entry);
    return base.length > 0 && style.length > 0 ? base + "-" + style : base;
}
