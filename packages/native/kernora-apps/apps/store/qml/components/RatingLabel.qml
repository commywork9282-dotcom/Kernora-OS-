/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kernora.m3

Row {
    id: root

    property real value: 0
    property color color: M3.surfaceVariantContent
    property string role: "bodySmall"

    spacing: 3
    visible: value > 0

    MText {
        id: number
        role: root.role
        text: Number(root.value).toLocaleString(Qt.locale(), "f", 1)
        color: root.color
    }
    MIcon {
        anchors.verticalCenter: number.verticalCenter
        size: Math.round(number.lineHeight * 0.75)
        source: "rating"
        color: root.color
    }
}
