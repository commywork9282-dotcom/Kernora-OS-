// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

let watched = null;

workspace.windowAdded.connect(window => {
    if (!watched && window && window.appletPopup === true) {
        watched = window;
    }
});

workspace.windowRemoved.connect(window => {
    if (watched && window === watched) {
        watched = null;
        callDBus("invalid.kernora.kernora-welcome", "/invalid/kernora/kernora_welcome",
                 "org.freedesktop.Application", "Activate", {});
    }
});
