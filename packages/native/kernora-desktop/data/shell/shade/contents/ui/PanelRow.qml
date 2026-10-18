/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import "m3"

Item {
    id: row

    property string icon
    property string title
    property string subtitle
    property string trailingIcon
    property bool active: false
    property bool busy: false

    signal clicked()

    implicitHeight: 56

    MMorph { id: pressMorph; active: mouse.pressed }

    Rectangle {
        id: surface
        anchors.fill: parent
        radius: 20 - 8 * pressMorph.value
        color: row.active ? M3.primaryContainer : "transparent"
        Behavior on color { ColorAnimation { duration: M3.durationMedium2 } }

        MStateLayer {
            radius: surface.radius
            color: row.active ? M3.primaryContainerContent : M3.surfaceContent
            hovered: mouse.containsMouse
            pressed: mouse.pressed
            pressPoint: Qt.point(mouse.mouseX, mouse.mouseY)
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 12

        Item {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            MMorph { id: activeMorph; active: row.active }
            Rectangle {
                anchors.fill: parent
                radius: 18 - 6 * activeMorph.value
                color: row.active ? M3.primary : M3.withAlpha(M3.surfaceContent, 0.08)
            }
            MIcon {
                anchors.centerIn: parent
                size: 20
                source: row.icon
                color: row.active ? M3.primaryContent : M3.surfaceContent
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            MText {
                Layout.fillWidth: true
                role: "titleSmall"
                text: row.title
                elide: Text.ElideRight
                color: row.active ? M3.primaryContainerContent : M3.surfaceContent
            }
            MText {
                Layout.fillWidth: true
                visible: text.length > 0
                role: "bodySmall"
                text: row.subtitle
                elide: Text.ElideRight
                color: row.active ? M3.primaryContainerContent : M3.surfaceVariantContent
            }
        }
        MCircularProgress {
            visible: row.busy
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            running: visible
        }
        MIcon {
            visible: row.trailingIcon.length > 0 && !row.busy
            size: 16
            source: row.trailingIcon
            color: row.active ? M3.primaryContainerContent : M3.surfaceVariantContent
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.clicked()
    }
}
