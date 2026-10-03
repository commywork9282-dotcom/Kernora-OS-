/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.desktop as Desktop
import "private" as P

Desktop.Switch {
    id: control

    spacing: 10

    indicator: P.SwitchIndicator {
        control: control
        x: control.contentItem !== null && control.contentItem.width > 0
            ? (control.mirrored ? control.width - width - control.rightPadding : control.leftPadding)
            : control.leftPadding + (control.availableWidth - width) / 2
        y: control.topPadding + Math.round((control.availableHeight - height) / 2)
    }
}
