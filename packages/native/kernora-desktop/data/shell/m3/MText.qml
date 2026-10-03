/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

Text {
    id: root

    property string role: "bodyMedium"

    font: M3[role]
    lineHeight: M3[role + "LineHeight"]
    lineHeightMode: Text.FixedHeight
    color: M3.surfaceContent
    textFormat: Text.PlainText
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
    renderType: Text.QtRendering

    Behavior on color {
        ColorAnimation {
            duration: M3.durationMedium1
            easing.type: Easing.Bezier
            easing.bezierCurve: M3.easingStandard
        }
    }
}
