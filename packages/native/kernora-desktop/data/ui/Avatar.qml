/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Effects
import org.kernora.m3

Item {
    id: root

    property url source
    property string initials
    property int size: 48

    implicitWidth: size
    implicitHeight: size

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: M3.primaryContainer
        visible: picture.status !== Image.Ready
        MText {
            anchors.centerIn: parent
            text: root.initials
            color: M3.primaryContainerContent
            font.pixelSize: Math.round(root.size * 0.42)
            font.weight: Font.Medium
        }
    }

    Image {
        id: picture
        anchors.fill: parent
        source: root.source
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        fillMode: Image.PreserveAspectCrop
        visible: false
        cache: false
    }
    Rectangle {
        id: mask
        anchors.fill: parent
        radius: width / 2
        visible: false
        layer.enabled: true
    }
    MultiEffect {
        anchors.fill: parent
        source: picture
        visible: picture.status === Image.Ready
        maskEnabled: true
        maskSource: mask
    }
}
