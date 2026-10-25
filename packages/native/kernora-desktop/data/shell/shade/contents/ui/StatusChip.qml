/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import "m3"

Item {
    id: root

    required property QtObject controller
    required property QtObject backend

    readonly property bool active: controller.opening
    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool twelveHour: !backend.timeFormat.includes("H")
    readonly property string hourText: {
        const hour = backend.now.getHours();
        return twelveHour ? String(hour % 12 || 12) : String(hour).padStart(2, "0");
    }

    Layout.minimumWidth: vertical ? 0 : implicitWidth
    Layout.preferredWidth: vertical ? -1 : implicitWidth
    Layout.maximumWidth: vertical ? Number.POSITIVE_INFINITY : implicitWidth
    Layout.minimumHeight: vertical ? implicitHeight : 0
    Layout.preferredHeight: vertical ? implicitHeight : -1
    Layout.maximumHeight: vertical ? implicitHeight : Number.POSITIVE_INFINITY
    Layout.fillHeight: !vertical
    Layout.fillWidth: vertical
    implicitWidth: vertical ? 40 : content.implicitWidth + 32
    implicitHeight: vertical ? column.implicitHeight + 28 : 40

    Accessible.role: Accessible.Button
    Accessible.name: i18n("Quick Settings")
    Accessible.description: backend.timeText

    Rectangle {
        id: pill
        x: root.vertical ? Math.round((parent.width - width) / 2) : 0
        y: root.vertical ? 0 : Math.round((parent.height - height) / 2)
        width: root.vertical ? Math.min(parent.width, 40) : parent.width
        height: root.vertical ? parent.height : Math.min(parent.height, 40)
        radius: Math.min(width, height) / 2
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
            visible: !root.vertical

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

        ColumnLayout {
            id: column
            anchors.centerIn: parent
            spacing: 6
            visible: root.vertical

            MIcon {
                Layout.alignment: Qt.AlignHCenter
                size: 20
                source: root.backend.networkIcon
                color: pill.ink
            }
            MIcon {
                Layout.alignment: Qt.AlignHCenter
                size: 20
                source: root.backend.volumeIcon
                color: pill.ink
            }
            MIcon {
                Layout.alignment: Qt.AlignHCenter
                size: 20
                visible: root.backend.hasBattery
                source: root.backend.batteryIcon
                color: pill.ink
            }
            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 2
                spacing: -4
                MText {
                    Layout.alignment: Qt.AlignHCenter
                    role: "labelLarge"
                    text: root.hourText
                    color: pill.ink
                }
                MText {
                    Layout.alignment: Qt.AlignHCenter
                    role: "labelLarge"
                    text: Qt.formatTime(root.backend.now, "mm")
                    color: pill.ink
                }
            }
        }

        MStateLayer {
            radius: pill.radius
            color: pill.ink
            hovered: mouse.containsMouse
            pressed: mouse.pressed && !root.controller.dragging
            pressPoint: Qt.point(mouse.mouseX - pill.x, mouse.mouseY - pill.y)
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
