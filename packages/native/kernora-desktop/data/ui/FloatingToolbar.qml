/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami
import org.kernora.m3

Item {
    id: root

    property bool vibrant: false
    property bool shown: true
    default property alias buttons: row.data
    readonly property color fill: vibrant ? M3.primaryContainer : M3.surfaceContainer
    readonly property color ink: vibrant ? M3.primaryContainerContent : M3.surfaceVariantContent
    readonly property color checkedFill: vibrant ? M3.primary : M3.secondaryContainer
    readonly property color checkedInk: vibrant ? M3.primaryContent : M3.secondaryContainerContent

    implicitWidth: row.implicitWidth + 16
    implicitHeight: 64
    visible: showMorph.value > 0.01
    opacity: Math.min(1, showMorph.value * 1.6)

    MMorph {
        id: showMorph
        active: root.shown
        dampingRatio: M3.springExpressiveDefaultDamping
        response: M3.springExpressiveDefaultResponse
    }

    transform: [
        Scale {
            origin.x: root.width / 2
            origin.y: root.height
            xScale: 0.85 + 0.15 * showMorph.value
            yScale: 0.85 + 0.15 * showMorph.value
        },
        Translate { y: (1 - showMorph.value) * 24 }
    ]

    Kirigami.ShadowedRectangle {
        anchors.fill: parent
        radius: M3.classic ? M3.cornerSheet : height / 2
        color: root.fill
        readonly property var shadowSpec: M3.elevationOf("fab")
        shadow.xOffset: 0
        shadow.yOffset: shadowSpec.offset
        shadow.size: shadowSpec.blur
        shadow.color: Qt.rgba(0, 0, 0, shadowSpec.opacity)
        Behavior on color { ColorAnimation { duration: M3.durationShort4 } }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4
    }
}
