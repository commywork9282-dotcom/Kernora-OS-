/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kernora.m3

Rectangle {
    id: root

    property bool installed: false
    property bool busy: false
    property bool hasUpdate: false
    property int progress: -1

    implicitWidth: row.implicitWidth + 16
    implicitHeight: 24
    radius: 12
    visible: installed || busy || hasUpdate
    color: hasUpdate && !busy ? M3.tertiaryContainer : M3.secondaryContainer

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 4

        MIcon {
            size: 14
            visible: !root.busy
            source: root.hasUpdate ? "system-software-update" : "checkmark"
            color: root.hasUpdate ? M3.tertiaryContainerContent : M3.secondaryContainerContent
        }
        MText {
            role: "labelMedium"
            text: root.busy ? (root.progress >= 0 ? i18n("%1%", root.progress) : i18n("Working…"))
                : root.hasUpdate ? i18n("Update") : i18n("Installed")
            color: root.hasUpdate && !root.busy ? M3.tertiaryContainerContent : M3.secondaryContainerContent
        }
    }
}
