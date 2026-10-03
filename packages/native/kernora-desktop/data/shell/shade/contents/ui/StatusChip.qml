/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import "m3"

Item {
    id: root

    required property QtObject controller
    required property QtObject backend

    readonly property bool active: controller.opening

    Layout.minimumWidth: implicitWidth
    Layout.preferredWidth: implicitWidth
    Layout.maximumWidth: implicitWidth
    Layout.fillHeight: true
    implicitWidth: content.implicitWidth + 32
    implicitHeight: 40

    Accessible.role: Accessible.Button
    Accessible.name: i18n("Quick Settings")
    Accessible.description: backend.timeText

    Rectangle {
        id: pill
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: Math.min(parent.height, 40)
        radius: height / 2
        color: root.active ? M3.secondaryContainer : M3.surfaceContainerHighest

        Behavior on color {
            ColorAnimation {
                duration: M3.durationMedium2
                easing.type: Easing.Bezier
                easing.bezierCurve: M3.easingEmphasized
            }
        }

        readonly property color ink: root.active ? M3.secondaryContainerContent : M3.surfaceContent

        RowLayout {
            id: content
            anchors.centerIn: parent
            spacing: 8

            MIcon {
                size: 20
                source: root.backend.networkIcon
                color: pill.ink
            }
            MIcon {
                size: 20
                source: root.backend.volumeIcon
                color: pill.ink
            }
            MIcon {
                size: 20
                visible: root.backend.hasBattery
                source: root.backend.batteryIcon
                color: pill.ink
            }
            MText {
                Layout.leftMargin: 4
                role: "labelLarge"
                text: root.backend.timeText
                color: pill.ink
            }
        }

        MStateLayer {
            radius: pill.radius
            color: pill.ink
            hovered: mouse.containsMouse
            pressed: mouse.pressed && !root.controller.dragging
            pressPoint: Qt.point(mouse.mouseX, mouse.mouseY - pill.y)
        }
    }

    MouseArea {
        id: mouse

        property real pressY: 0
        property bool draggingShade: false

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: draggingShade ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        preventStealing: true

        onPressed: event => {
            pressY = event.y;
            draggingShade = false;
        }
        onPositionChanged: event => {
            if (!pressed) {
                return;
            }
            const upwards = pressY - event.y;
            if (!draggingShade && Math.abs(upwards) > Qt.styleHints.startDragDistance) {
                draggingShade = true;
                root.controller.beginDrag();
            }
            if (draggingShade) {
                root.controller.dragTo(upwards);
            }
        }
        onReleased: {
            if (draggingShade) {
                draggingShade = false;
                root.controller.endDrag();
            } else {
                root.controller.toggle();
            }
        }
        onCanceled: {
            if (draggingShade) {
                draggingShade = false;
                root.controller.cancelDrag();
            }
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            if (event.pixelDelta.y !== 0) {
                root.controller.scrollBy(event.inverted ? -event.pixelDelta.y : event.pixelDelta.y);
            } else if (event.angleDelta.y !== 0) {
                const up = event.inverted ? -event.angleDelta.y : event.angleDelta.y;
                root.controller.wheelNotch(up > 0);
            }
        }
    }
}
