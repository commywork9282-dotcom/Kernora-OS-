/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import "m3"

Rectangle {
    id: group

    default property alias rows: column.data

    implicitHeight: column.implicitHeight + 8
    radius: 24
    color: M3.surfaceContainerHighest

    Column {
        id: column
        x: 4
        y: 4
        width: parent.width - 8
        spacing: 2
    }
}
