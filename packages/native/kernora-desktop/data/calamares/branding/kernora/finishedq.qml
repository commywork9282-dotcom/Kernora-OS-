/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import io.calamares.core 1.0
import io.calamares.ui 1.0

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kernora.m3
import org.kernora.ui

Item {
    id: finished

    Rectangle {
        anchors.fill: parent
        color: M3.surface
    }

    readonly property string doneText: qsTr("%1 has been installed on your computer.<br/>
            You may now restart into your new system, or continue using the Live environment.")
            .arg(Branding.string(Branding.ProductName))

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 560)
        spacing: 16

        Rectangle {
            id: badge
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 128
            implicitHeight: 128
            radius: 64 - 24 * arrive.value
            rotation: -45 * (1 - arrive.value)
            color: config.failed ? M3.errorContainer : M3.primaryContainer
            MMorph {
                id: arrive
                active: finished.visible
                dampingRatio: 0.55
                response: 0.6
            }
            MIcon {
                anchors.centerIn: parent
                rotation: -badge.rotation
                size: 64
                source: config.failed ? "dialog-error" : "checkmark"
                color: config.failed ? M3.errorContainerContent : M3.primaryContainerContent
            }
        }

        MText {
            Layout.fillWidth: true
            Layout.topMargin: 12
            role: "headlineMedium"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: config.failed ? config.failureMessage : qsTr("Installation Completed")
        }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            textFormat: Text.StyledText
            font: M3.bodyLarge
            color: M3.surfaceVariantContent
            text: config.failed ? config.failureDetails : finished.doneText.replace(/<br\/>\s*/g, " ")
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 20
            spacing: 12
            Button {
                text: qsTr("Close Installer")
                flat: true
                onClicked: ViewManager.quit()
            }
            Button {
                visible: !config.failed
                text: qsTr("Restart System")
                highlighted: true
                onClicked: config.doRestart(true)
            }
        }
    }

    function onActivate() {}
    function onLeave() {}
}
