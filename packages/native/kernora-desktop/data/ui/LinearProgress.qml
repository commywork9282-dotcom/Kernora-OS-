/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kernora.m3

Item {
    id: root

    property real value: 0
    property bool indeterminate: false

    implicitWidth: 240
    implicitHeight: 4

    readonly property real gap: 4

    Rectangle {
        visible: !root.indeterminate
        width: Math.max(0, root.width * root.value)
        height: parent.height
        radius: M3.classic ? 0 : height / 2
        color: M3.primary
        Behavior on width { NumberAnimation { duration: M3.durationMedium2; easing.type: Easing.Bezier; easing.bezierCurve: M3.easingStandard } }
    }
    Rectangle {
        visible: !root.indeterminate && x < root.width - 2
        x: root.width * root.value + (root.value > 0 ? root.gap : 0)
        width: Math.max(0, root.width - x)
        height: parent.height
        radius: M3.classic ? 0 : height / 2
        color: M3.secondaryContainer
        Rectangle {
            anchors.right: parent.right
            width: root.height
            height: root.height
            radius: M3.classic ? 0 : width / 2
            color: M3.primary
        }
    }

    Rectangle {
        visible: root.indeterminate
        anchors.fill: parent
        radius: M3.classic ? 0 : height / 2
        color: M3.secondaryContainer
    }
    Item {
        visible: root.indeterminate
        anchors.fill: parent
        clip: true
        property real phase: 0
        NumberAnimation on phase {
            running: root.indeterminate && root.visible
            from: 0
            to: 1
            duration: 1800
            loops: Animation.Infinite
        }
        Rectangle {
            x: (parent.phase * 1.6 - 0.4) * root.width
            width: root.width * 0.36
            height: parent.height
            radius: M3.classic ? 0 : height / 2
            color: M3.primary
        }
    }
}
