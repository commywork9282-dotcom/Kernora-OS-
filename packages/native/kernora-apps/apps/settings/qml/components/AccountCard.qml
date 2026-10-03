/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kernora.m3
import org.kernora.ui
import org.kernora.system

Item {
    id: root

    property bool current: false
    signal clicked()

    implicitHeight: 80
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: Accounts.displayName
    Accessible.onPressAction: clicked()
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()

    Rectangle {
        id: surface
        anchors.fill: parent
        radius: M3.classic ? M3.cornerCard : 28
        color: root.current ? M3.secondaryContainer : M3.surfaceContainerHigh
        Behavior on color { ColorAnimation { duration: M3.durationShort4 } }
        MStateLayer {
            radius: surface.radius
            color: M3.surfaceContent
            hovered: mouse.containsMouse
            pressed: mouse.pressed
            focused: root.activeFocus
            pressPoint: Qt.point(mouse.mouseX, mouse.mouseY)
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 18
        spacing: 14

        Avatar {
            size: 52
            source: Accounts.avatar
            initials: Accounts.initials
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            MText {
                Layout.fillWidth: true
                role: "titleMedium"
                text: Accounts.displayName
                elide: Text.ElideRight
                color: root.current ? M3.secondaryContainerContent : M3.surfaceContent
            }
            MText {
                Layout.fillWidth: true
                role: "bodyMedium"
                text: i18n("Account, picture, password")
                elide: Text.ElideRight
                color: root.current ? M3.secondaryContainerContent : M3.surfaceVariantContent
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
