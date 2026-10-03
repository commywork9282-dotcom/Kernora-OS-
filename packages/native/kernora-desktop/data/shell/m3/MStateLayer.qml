/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Effects

Item {
    id: root

    anchors.fill: parent

    property real radius: 0
    property real topLeftRadius: radius
    property real topRightRadius: radius
    property real bottomLeftRadius: radius
    property real bottomRightRadius: radius
    readonly property real safeTopLeft: Math.max(0, topLeftRadius)
    readonly property real safeTopRight: Math.max(0, topRightRadius)
    readonly property real safeBottomLeft: Math.max(0, bottomLeftRadius)
    readonly property real safeBottomRight: Math.max(0, bottomRightRadius)
    property color color: M3.surfaceContent
    property bool hovered: false
    property bool pressed: false
    property bool focused: false
    property bool dragged: false
    property point pressPoint: Qt.point(width / 2, height / 2)
    property bool rippleEnabled: true

    Rectangle {
        anchors.fill: parent
        topLeftRadius: root.safeTopLeft
        topRightRadius: root.safeTopRight
        bottomLeftRadius: root.safeBottomLeft
        bottomRightRadius: root.safeBottomRight
        color: root.color
        opacity: {
            if (root.dragged) {
                return M3.stateDragged;
            }
            if (root.pressed && !root.rippleEnabled) {
                return M3.statePressed;
            }
            if (root.focused) {
                return M3.stateFocus;
            }
            return root.hovered ? M3.stateHover : 0;
        }
        Behavior on opacity {
            NumberAnimation {
                duration: M3.durationShort4
                easing.type: Easing.Bezier
                easing.bezierCurve: M3.easingStandard
            }
        }
    }

    onPressedChanged: {
        if (!rippleEnabled) {
            return;
        }
        if (pressed) {
            fadeOut.stop();
            const p = pressPoint;
            const dx = Math.max(p.x, width - p.x);
            const dy = Math.max(p.y, height - p.y);
            wave.finalSize = 2 * Math.sqrt(dx * dx + dy * dy);
            wave.cx = p.x;
            wave.cy = p.y;
            grow.restart();
        } else {
            fadeOut.restart();
        }
    }

    Item {
        id: waves
        anchors.fill: parent
        visible: false
        layer.enabled: wave.opacity > 0

        Rectangle {
            id: wave

            property real finalSize: 0
            property real cx: 0
            property real cy: 0
            property real size: 0

            width: size
            height: size
            radius: size / 2
            x: cx - size / 2
            y: cy - size / 2
            color: root.color
            opacity: 0
        }
    }

    Rectangle {
        id: clipShape
        anchors.fill: parent
        topLeftRadius: root.safeTopLeft
        topRightRadius: root.safeTopRight
        bottomLeftRadius: root.safeBottomLeft
        bottomRightRadius: root.safeBottomRight
        visible: false
        layer.enabled: wave.opacity > 0
    }

    MultiEffect {
        anchors.fill: parent
        visible: wave.opacity > 0
        source: waves
        maskEnabled: true
        maskSource: clipShape
    }

    ParallelAnimation {
        id: grow
        NumberAnimation {
            target: wave
            property: "size"
            from: wave.finalSize * 0.2
            to: wave.finalSize
            duration: M3.durationLong2
            easing.type: Easing.Bezier
            easing.bezierCurve: M3.easingEmphasizedDecelerate
        }
        NumberAnimation {
            target: wave
            property: "opacity"
            to: M3.statePressed + 0.02
            duration: M3.durationShort2
        }
    }

    SequentialAnimation {
        id: fadeOut
        PauseAnimation {
            duration: grow.running ? M3.durationShort3 : 0
        }
        NumberAnimation {
            target: wave
            property: "opacity"
            to: 0
            duration: M3.durationMedium2
            easing.type: Easing.Bezier
            easing.bezierCurve: M3.easingStandard
        }
    }
}
