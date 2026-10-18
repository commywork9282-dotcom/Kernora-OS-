/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import "m3"

Item {
    id: root

    property bool active: false

    signal clicked()

    Layout.minimumWidth: 40
    Layout.preferredWidth: 40
    Layout.maximumWidth: 40
    Layout.fillHeight: true
    implicitWidth: 40
    implicitHeight: 40

    Accessible.role: Accessible.Button
    Accessible.name: i18n("Applications")

    Rectangle {
        id: circle
        anchors.centerIn: parent
        width: 40
        height: 40
        radius: 20 - 8 * pressMorph.value
        color: root.active ? M3.primary : M3.surfaceContainerHighest

        MMorph { id: pressMorph; active: mouse.pressed && !M3.classic }
        Behavior on color {
            ColorAnimation {
                duration: M3.durationMedium2
                easing.type: Easing.Bezier
                easing.bezierCurve: M3.easingEmphasized
            }
        }

        MIcon {
            anchors.centerIn: parent
            size: 24
            source: "start-here-kde-symbolic"
            color: root.active ? M3.primaryContent : M3.surfaceContent
            rotation: root.active ? 90 : 0
            Behavior on rotation {
                NumberAnimation {
                    duration: M3.durationLong2
                    easing.type: Easing.Bezier
                    easing.bezierCurve: M3.easingEmphasized
                }
            }
        }

        MStateLayer {
            radius: circle.radius
            color: root.active ? M3.primaryContent : M3.surfaceContent
            hovered: mouse.containsMouse
            pressed: mouse.pressed
            pressPoint: Qt.point(mouse.mouseX - circle.x, mouse.mouseY - circle.y)
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
