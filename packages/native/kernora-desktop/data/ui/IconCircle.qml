/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kernora.m3

Rectangle {
    id: root

    property string icon
    property int accent: -1
    property int size: 40
    property int iconSize: Math.round(size * 0.55)
    property color containerColor: accent >= 0 ? M3.accent(accent).container : M3.secondaryContainer
    property color contentColor: accent >= 0 ? M3.accent(accent).content : M3.secondaryContainerContent

    implicitWidth: size
    implicitHeight: size
    radius: size / 2
    color: containerColor

    MIcon {
        anchors.centerIn: parent
        size: root.iconSize
        source: root.icon
        color: root.contentColor
    }
}
