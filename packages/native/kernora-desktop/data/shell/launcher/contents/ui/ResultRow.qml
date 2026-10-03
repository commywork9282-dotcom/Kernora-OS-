/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami
import "m3"

Item {
    id: root

    property string title
    property string subtitle
    property var iconSource
    property bool current: false

    signal clicked()

    implicitHeight: 64

    Accessible.role: Accessible.ListItem
    Accessible.name: title
    Accessible.description: subtitle

    Rectangle {
        id: container
        anchors.fill: parent
        radius: M3.classic ? M3.cornerListItem : 20
        color: root.current ? M3.secondaryContainer : "transparent"
        Behavior on color { ColorAnimation { duration: M3.durationShort3 } }

        Rectangle {
            id: badge
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            height: 40
            radius: 20
            color: root.current ? M3.surfaceContainerLowest : M3.surfaceContainerHighest
            Behavior on color { ColorAnimation { duration: M3.durationShort3 } }

            Kirigami.Icon {
                anchors.centerIn: parent
                width: 28
                height: 28
                source: root.iconSource
                animated: false
            }
        }

        Column {
            anchors.left: badge.right
            anchors.leftMargin: 16
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter

            MText {
                width: parent.width
                role: "bodyLarge"
                text: root.title
                color: root.current ? M3.secondaryContainerContent : M3.surfaceContent
            }
            MText {
                width: parent.width
                role: "bodyMedium"
                text: root.subtitle
                visible: text.length > 0 && text !== root.title
                color: M3.surfaceVariantContent
            }
        }

        MStateLayer {
            radius: container.radius
            color: M3.surfaceContent
            hovered: mouse.containsMouse
            pressed: mouse.pressed
            pressPoint: Qt.point(mouse.mouseX, mouse.mouseY)
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
