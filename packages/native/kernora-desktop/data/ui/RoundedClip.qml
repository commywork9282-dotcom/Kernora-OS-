/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Effects

Item {
    id: root

    property real radius: 28
    default property alias content: container.data

    Item {
        id: container
        anchors.fill: parent
        layer.enabled: true
        layer.smooth: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: mask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
    }

    Rectangle {
        id: mask
        anchors.fill: parent
        radius: root.radius
        antialiasing: true
        visible: false
        layer.enabled: true
        layer.smooth: true
    }
}
