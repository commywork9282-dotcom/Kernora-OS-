/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import "m3"

Item {
    id: root

    property bool active: false

    signal pressed()
    signal clicked()

    implicitWidth: 72
    implicitHeight: 40

    Accessible.role: Accessible.Button
    Accessible.name: i18n("Applications")

    Rectangle {
        id: pill
        anchors.centerIn: parent
        width: 72
        height: 40
        radius: height / 2
        color: root.active ? M3.primary : M3.surfaceContainerHighest

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
            color: root.active ? M3.primaryContent : M3.surfaceVariantContent
            scale: mouse.pressed ? 0.9 : 1

            Behavior on scale {
                NumberAnimation {
                    duration: M3.durationShort3
                    easing.type: Easing.Bezier
                    easing.bezierCurve: M3.easingStandard
                }
            }
        }

        MStateLayer {
            radius: pill.radius
            color: root.active ? M3.primaryContent : M3.surfaceContent
            hovered: mouse.containsMouse
            pressed: mouse.pressed
            pressPoint: Qt.point(mouse.mouseX - pill.x, mouse.mouseY - pill.y)
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onPressed: root.pressed()
        onClicked: root.clicked()
    }
}
