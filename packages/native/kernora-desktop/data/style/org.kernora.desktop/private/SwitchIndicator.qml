/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Templates as T
import org.kde.kirigami as Kirigami
import "../impl"

Item {
    id: indicator

    property T.AbstractButton control

    implicitWidth: 46
    implicitHeight: 28
    opacity: control.enabled ? 1 : M3.stateDisabledContent + 0.1

    readonly property bool on: control.checked
    readonly property real position: travel.value

    MSpring {
        id: travel
        dampingRatio: 0.72
        response: M3.springSpatialFastResponse
    }

    Connections {
        target: indicator.control
        function onVisualPositionChanged(): void {
            if (indicator.control.pressed) {
                travel.jumpTo(indicator.control.visualPosition);
            } else {
                travel.animateTo(indicator.control.visualPosition, travel.velocity);
            }
        }
        function onPressedChanged(): void {
            if (!indicator.control.pressed) {
                travel.animateTo(indicator.control.visualPosition, travel.velocity);
            }
        }
    }
    Component.onCompleted: travel.jumpTo(control.visualPosition)

    Rectangle {
        id: track

        anchors.centerIn: parent
        width: M3.classic ? 34 : indicator.width
        height: M3.classic ? 14 : indicator.height
        radius: height / 2
        color: M3.classic
            ? (indicator.on ? M3.withAlpha(M3.secondary, 0.5) : M3.withAlpha(M3.surfaceContent, 0.38))
            : indicator.on ? M3.primary : M3.surfaceContainerHighest
        border.width: indicator.on || M3.classic ? 0 : 2
        border.color: M3.outline

        Behavior on color {
            enabled: M3.motionScale > 0
            ColorAnimation {
                duration: M3.durationShort4
                easing.type: Easing.Bezier
                easing.bezierCurve: M3.easingStandard
            }
        }
    }

    Item {
        id: slot

        readonly property real centerX: track.x + track.height / 2 + indicator.position * (track.width - track.height)
        x: centerX - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: 36
        height: 36

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: indicator.on ? M3.primary : M3.surfaceContent
            opacity: indicator.control.pressed ? M3.statePressed
                   : indicator.control.visualFocus ? M3.stateFocus
                   : indicator.control.hovered ? M3.stateHover : 0
            Behavior on opacity {
                enabled: M3.motionScale > 0
                NumberAnimation { duration: M3.durationShort4 }
            }
        }

        Kirigami.ShadowedRectangle {
            id: handle

            anchors.centerIn: parent
            readonly property real diameter: M3.classic ? 20 : indicator.control.pressed ? 24 : 14 + 6 * indicator.position
            width: diameter
            height: diameter
            radius: diameter / 2
            shadow.size: M3.classic ? 3 : 0
            shadow.yOffset: M3.classic ? 1 : 0
            shadow.color: Qt.rgba(0, 0, 0, 0.35)
            color: M3.classic
                ? (indicator.on ? M3.secondary : M3.dark ? "#bdbdbd" : "#fafafa")
                : indicator.on
                ? (indicator.control.hovered || indicator.control.pressed ? M3.primaryContainer : M3.primaryContent)
                : (indicator.control.hovered || indicator.control.pressed ? M3.surfaceVariantContent : M3.outline)

            Behavior on width {
                enabled: M3.motionScale > 0
                NumberAnimation { duration: M3.durationShort3 }
            }
            Behavior on height {
                enabled: M3.motionScale > 0
                NumberAnimation { duration: M3.durationShort3 }
            }
            Behavior on color {
                enabled: M3.motionScale > 0
                ColorAnimation { duration: M3.durationShort4 }
            }

            MIcon {
                anchors.centerIn: parent
                size: 14
                source: "checkmark"
                color: M3.primaryContainerContent
                opacity: Math.max(0, indicator.position * 2 - 1)
                visible: opacity > 0 && !M3.classic
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: height / 2
        color: "transparent"
        border.width: 2
        border.color: M3.secondary
        visible: indicator.control.visualFocus
    }
}
