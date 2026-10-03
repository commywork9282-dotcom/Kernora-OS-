/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import org.kernora.m3
import org.kernora.ui

Page {
    id: page

    readonly property var app: QQC2.ApplicationWindow.window

    canGoBack: app ? app.canGoBack && (QQC2.StackView.index > 0 || app.narrow) : false
    cornerRadius: app && !app.narrow ? (M3.classic ? M3.cornerCard : 28) : 0
    onBack: app.goBack()

    function open(file: string, properties: var): void {
        app.openPage(file, properties || {});
    }

    function notify(text: string): void {
        app.showMessage(text, "", null);
    }
}
