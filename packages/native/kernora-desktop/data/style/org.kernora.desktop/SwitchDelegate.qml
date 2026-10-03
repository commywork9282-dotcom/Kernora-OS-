/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.desktop as Desktop
import "private" as P

Desktop.SwitchDelegate {
    id: control

    indicator: P.SwitchIndicator {
        control: control
        x: !control.mirrored ? control.horizontalPadding : control.width - width - control.horizontalPadding
        y: control.topPadding + (control.availableHeight - height) / 2
    }

    background: P.ListItemBackground {
        anchors.fill: parent
        control: control
    }
}
