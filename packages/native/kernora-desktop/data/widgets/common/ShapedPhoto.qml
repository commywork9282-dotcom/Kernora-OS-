/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Effects

Item {
    id: root

    property url source
    property string shape: "cookie9"
    property real radius: 28
    readonly property bool ready: photo.status === Image.Ready
    readonly property bool fill: shape === "fill"

    Image {
        id: photo
        anchors.fill: parent
        source: root.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize: Qt.size(Math.max(width, height) * 2, Math.max(width, height) * 2)
        visible: false
    }

    Item {
        id: mask
        anchors.fill: parent
        visible: false
        layer.enabled: true

        MaterialShape {
            anchors.fill: parent
            visible: !root.fill
            shape: root.fill ? "circle" : root.shape
            color: "white"
        }

        Rectangle {
            anchors.fill: parent
            visible: root.fill
            radius: root.radius
            color: "white"
        }
    }

    MultiEffect {
        anchors.fill: parent
        visible: root.ready
        source: photo
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }
}
