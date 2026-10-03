/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import io.calamares.ui 1.0
import io.calamares.core 1.0

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kernora.m3

Rectangle {
    id: navigationBar

    color: M3.surfaceContainer
    height: 64

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 8

        Button {
            text: ViewManager.quitLabel
            flat: true
            enabled: ViewManager.quitEnabled
            visible: ViewManager.quitVisible && ViewManager.currentStepIndex < ViewManager.rowCount() - 1
            ToolTip.visible: hovered && ViewManager.quitTooltip.length > 0
            ToolTip.delay: 800
            ToolTip.text: ViewManager.quitTooltip
            onClicked: ViewManager.quit()
        }
        Item {
            Layout.fillWidth: true
        }
        Button {
            text: ViewManager.backLabel
            enabled: ViewManager.backEnabled
            visible: ViewManager.backAndNextVisible && ViewManager.currentStepIndex < ViewManager.rowCount() - 1
            onClicked: ViewManager.back()
        }
        Button {
            text: ViewManager.nextLabel
            highlighted: true
            enabled: ViewManager.nextEnabled
            visible: ViewManager.backAndNextVisible && ViewManager.currentStepIndex < ViewManager.rowCount() - 1
            onClicked: ViewManager.next()
        }
    }
}
