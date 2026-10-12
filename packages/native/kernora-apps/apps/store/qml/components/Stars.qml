/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kernora.m3

Row {
    id: root

    property real value: 0
    property int size: 14
    property color color: M3.primary

    spacing: 1
    visible: value > 0

    Repeater {
        model: 5
        delegate: MIcon {
            required property int index
            size: root.size
            source: "rating"
            color: root.color
            opacity: root.value >= index + 0.75 ? 1 : root.value >= index + 0.25 ? 0.6 : 0.22
        }
    }
}
