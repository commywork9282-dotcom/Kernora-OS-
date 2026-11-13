/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

Text {
    id: root

    property string role: "bodyMedium"
    property bool rounded: false

    font: rounded ? roundedFont : M3[role]
    readonly property font roundedFont: {
        const value = M3[role];
        value.variableAxes = { "ROND": 100 };
        return value;
    }
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
