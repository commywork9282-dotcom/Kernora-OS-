/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Templates as T
import "impl"

T.MenuSeparator {
    id: control

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: visible ? Math.max(implicitBackgroundHeight + topInset + bottomInset,
                                       implicitContentHeight + topPadding + bottomPadding) : 0

    width: parent?.width

    topPadding: 4
    bottomPadding: 4
    hoverEnabled: false
    focusPolicy: Qt.NoFocus

    contentItem: Rectangle {
        implicitWidth: 160
        implicitHeight: 1
        color: M3.outlineVariant
    }
}
