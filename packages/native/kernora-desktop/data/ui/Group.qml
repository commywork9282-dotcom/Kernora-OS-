/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kernora.m3

Column {
    id: root

    property string title
    property string note
    default property alias rows: body.data

    width: parent ? parent.width : implicitWidth
    spacing: 8

    MText {
        x: 16
        width: root.width - 32
        role: "titleSmall"
        text: root.title
        color: M3.primary
        visible: text.length > 0
        bottomPadding: 4
    }

    Column {
        id: body
        width: root.width
        spacing: M3.classic ? 0 : 2
    }

    MText {
        x: 16
        width: root.width - 32
        role: "bodySmall"
        text: root.note
        color: M3.surfaceVariantContent
        visible: text.length > 0
        wrapMode: Text.Wrap
        lineHeightMode: Text.ProportionalHeight
        lineHeight: 1.15
    }
}
