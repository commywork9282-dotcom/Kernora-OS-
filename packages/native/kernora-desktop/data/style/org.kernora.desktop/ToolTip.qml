/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.desktop as Desktop
import "impl"

Desktop.ToolTip {
    id: control

    topPadding: 5
    bottomPadding: 5
    leftPadding: 9
    rightPadding: 9

    Kirigami.Theme.colorSet: Kirigami.Theme.Tooltip
    Kirigami.Theme.inherit: false

    enter: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: M3.motionScale > 0 ? M3.durationShort3 : 0
                easing.type: Easing.Bezier
                easing.bezierCurve: M3.easingStandard
            }
            NumberAnimation {
                property: "scale"
                from: 0.9
                to: 1
                duration: M3.motionScale > 0 ? M3.durationShort4 : 0
                easing.type: Easing.Bezier
                easing.bezierCurve: M3.easingEmphasizedDecelerate
            }
        }
    }

    exit: Transition {
        NumberAnimation {
            property: "opacity"
            to: 0
            duration: M3.motionScale > 0 ? M3.durationShort2 : 0
        }
    }

    contentItem: Item {
        implicitWidth: Math.min(label.maxTextLength, label.contentWidth)
        implicitHeight: label.implicitHeight

        Text {
            id: label
            readonly property real maxTextLength: Kirigami.Units.gridUnit * 14
            text: control.text.replace(/(&)(?!;)\S+(?>\s)/g, "")
            wrapMode: Text.Wrap
            font: control.font
            color: M3.inverseOnSurface
            onLineLaidOut: line => {
                if (line.implicitWidth > maxTextLength) {
                    line.width = maxTextLength;
                }
            }
        }
    }

    background: Kirigami.ShadowedRectangle {
        radius: M3.classic ? M3.cornerTooltip : 6
        color: M3.inverseSurface
        shadow.xOffset: 0
        shadow.yOffset: 2
        shadow.size: 8
        shadow.color: Qt.rgba(0, 0, 0, M3.dark ? 0.35 : 0.14)
    }
}
