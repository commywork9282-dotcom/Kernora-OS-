/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kernora.m3
import org.kernora.ui
import org.kernora.system
import "../components"

SettingsPage {
    id: page

    property string name
    property string path
    property string homepage

    title: name
    subtitle: path
    maximumContentWidth: 900

    actions: Component {
        IconButton {
            visible: page.homepage.length > 0
            iconName: "globe"
            text: i18n("Project website")
            onClicked: Qt.openUrlExternally(page.homepage)
        }
    }

    Rectangle {
        width: parent.width
        implicitHeight: text.implicitHeight + 40
        radius: M3.classic ? M3.cornerCard : 20
        color: M3.surfaceContainer

        TextEdit {
            id: text
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 20
            readOnly: true
            selectByMouse: true
            wrapMode: TextEdit.Wrap
            textFormat: TextEdit.PlainText
            font.family: "Hack"
            font.pixelSize: Math.round(M3.bodySmall.pixelSize)
            color: M3.surfaceContent
            selectionColor: M3.primaryContainer
            selectedTextColor: M3.primaryContainerContent
            text: Licenses.text(page.path) || i18n("The licence text is not installed.")
        }
    }
}
