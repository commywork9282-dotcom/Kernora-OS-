/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.desktop as Desktop
import "private" as P

Desktop.CheckDelegate {
    id: control

    background: P.ListItemBackground {
        anchors.fill: parent
        control: control
    }
}
