/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kernora.m3

Rectangle {
    id: root

    property string icon: "dialog-information"
    property string title
    property string text
    property string actionText
    property string tone: "info"
    signal actionTriggered()

    readonly property color ink: tone === "warning" ? M3.errorContainerContent
                               : tone === "neutral" ? M3.surfaceContent : M3.tertiaryContainerContent

    width: parent ? parent.width : implicitWidth
    implicitHeight: layout.implicitHeight + 32
    radius: M3.classic ? M3.cornerCard : 20
    color: tone === "warning" ? M3.errorContainer : tone === "neutral" ? M3.surfaceContainerHigh : M3.tertiaryContainer

    RowLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: 16
        anchors.leftMargin: 20
        spacing: 16
        MIcon {
            Layout.alignment: Qt.AlignTop
            size: 24
            source: root.icon
            color: root.ink
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            MText {
                Layout.fillWidth: true
                role: "titleSmall"
                text: root.title
                visible: text.length > 0
                color: root.ink
                wrapMode: Text.Wrap
            }
            MText {
                Layout.fillWidth: true
                role: "bodyMedium"
                text: root.text
                visible: text.length > 0
                color: root.ink
                wrapMode: Text.Wrap
                lineHeightMode: Text.ProportionalHeight
                lineHeight: 1.1
            }
        }
        QQC2.Button {
            visible: root.actionText.length > 0
            text: root.actionText
            onClicked: root.actionTriggered()
        }
    }
}
