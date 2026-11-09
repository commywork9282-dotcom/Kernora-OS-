/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import "m3"

Item {
    id: root

    required property int percent
    required property bool charging
    required property color ink
    required property color knockout

    readonly property bool low: !charging && percent <= 15
    readonly property color fill: charging ? "#3ddc84" : low ? M3.error : ink

    implicitWidth: body.width + nub.width + 1 + (bolt.visible ? bolt.width + 1 : 0)
    implicitHeight: 15

    Rectangle {
        id: body
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(26, label.implicitWidth + 8)
        height: 15
        radius: 5
        color: Qt.alpha(root.ink, 0.38)
        clip: true

        Rectangle {
            width: Math.round(parent.width * Math.max(0.12, Math.min(1, root.percent / 100)))
            height: parent.height
            radius: parent.radius
            color: root.fill
        }

        Text {
            id: label
            anchors.centerIn: parent
            text: root.percent
            color: root.knockout
            font.family: M3.typeface
            font.pixelSize: 11
            font.weight: Font.Bold
            font.features: { "tnum": 1 }
        }
    }

    Rectangle {
        id: nub
        anchors.left: body.right
        anchors.leftMargin: 1
        anchors.verticalCenter: parent.verticalCenter
        width: 2
        height: 6
        radius: 1
        color: root.percent >= 99 ? root.fill : Qt.alpha(root.ink, 0.38)
    }

    MIcon {
        id: bolt
        anchors.left: nub.right
        anchors.leftMargin: 1
        anchors.verticalCenter: parent.verticalCenter
        visible: root.charging
        size: 14
        source: "power-profile-performance"
        color: root.ink
    }
}
