/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kernora.m3

Rectangle {
    id: root

    property string icon: "dialog-information"
    property string text
    property bool warning: false

    implicitHeight: row.implicitHeight + 24
    radius: M3.classic ? M3.cornerCard : 12
    color: warning ? M3.errorContainer : M3.surfaceContainerHigh

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 12

        MIcon {
            Layout.alignment: Qt.AlignTop
            size: 20
            source: root.icon
            color: root.warning ? M3.errorContainerContent : M3.surfaceVariantContent
        }
        MText {
            Layout.fillWidth: true
            role: "bodyMedium"
            text: root.text
            wrapMode: Text.Wrap
            color: root.warning ? M3.errorContainerContent : M3.surfaceVariantContent
        }
    }
}
