/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kernora.m3

ColumnLayout {
    id: root

    property string icon
    property string title
    property string text
    property string actionText
    signal actionTriggered()

    width: parent ? parent.width : implicitWidth
    spacing: 12

    IconCircle {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 24
        size: 96
        iconSize: 48
        icon: root.icon
        containerColor: M3.surfaceContainerHigh
        contentColor: M3.surfaceVariantContent
    }
    MText {
        Layout.fillWidth: true
        Layout.topMargin: 8
        role: "titleLarge"
        text: root.title
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
    }
    MText {
        Layout.fillWidth: true
        role: "bodyMedium"
        text: root.text
        visible: text.length > 0
        color: M3.surfaceVariantContent
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
    }
    QQC2.Button {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 8
        visible: root.actionText.length > 0
        text: root.actionText
        onClicked: root.actionTriggered()
    }
}
