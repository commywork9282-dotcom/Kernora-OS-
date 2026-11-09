// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

const FRESH = 15000;
const opened = new Map();

function android(window) {
    return String(window.resourceClass || "").startsWith("waydroid.") && window.normalWindow;
}

function snapped(frame, client, scale) {
    const target = Math.round(client);
    const border = frame - client;
    const pixels = frame * scale;
    for (const candidate of [pixels, Math.floor(pixels), Math.ceil(pixels), Math.floor(pixels) - 1, Math.ceil(pixels) + 1]) {
        const size = candidate / scale;
        if (Math.round(Math.round(size * scale) / scale - border) === target) {
            return size;
        }
    }
    return frame;
}

function place(window, x, y) {
    const scale = (window.output && window.output.devicePixelRatio) || 1;
    const client = window.clientGeometry;
    const rect = window.frameGeometry;
    rect.width = snapped(rect.width, client.width, scale);
    rect.height = snapped(rect.height, client.height, scale);
    rect.x = Math.round(x);
    rect.y = Math.round(y);
    window.frameGeometry = rect;
}

function fit(window, old) {
    if (!android(window) || window.move || window.resize || window.fullScreen) {
        return;
    }
    const frame = window.frameGeometry;
    if (old && Math.round(old.width) === Math.round(frame.width) && Math.round(old.height) === Math.round(frame.height)) {
        return;
    }
    const area = workspace.clientArea(KWin.MaximizeArea, window);
    if (frame.width >= area.width && frame.height >= area.height) {
        return;
    }
    const inside = frame.x >= area.x && frame.y >= area.y
        && frame.x + frame.width <= area.x + area.width && frame.y + frame.height <= area.y + area.height;
    if (inside) {
        return;
    }
    let x = frame.x;
    let y = frame.y;
    if (Date.now() - (opened.get(window) || 0) < FRESH) {
        x = area.x + (area.width - frame.width) / 2;
        y = area.y + (area.height - frame.height) / 2;
    }
    x = Math.max(area.x, Math.min(x, area.x + area.width - frame.width));
    y = Math.max(area.y, Math.min(y, area.y + area.height - frame.height));
    place(window, x, y);
}

function question(window) {
    if (String(window.resourceClass || "") !== "org.kernora.androiddialog") {
        return false;
    }
    window.skipTaskbar = true;
    window.skipSwitcher = true;
    window.keepAbove = true;
    workspace.activeWindow = window;
    return true;
}

function watch(window) {
    if (question(window)) {
        return;
    }
    opened.set(window, Date.now());
    window.frameGeometryChanged.connect(old => fit(window, old));
    fit(window, null);
}

workspace.windowList().forEach(watch);
workspace.windowAdded.connect(watch);
workspace.windowRemoved.connect(window => opened.delete(window));
