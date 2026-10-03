/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import org.kernora.m3

QQC2.ApplicationWindow {
    id: root

    minimumWidth: 400
    minimumHeight: 420
    color: M3.surface

    function showMessage(text: string, actionText: string, action: var): void {
        snackbar.show(text, actionText, action);
    }

    Snackbar {
        id: snackbar
        parent: root.QQC2.Overlay.overlay
        z: 1000
    }
}
