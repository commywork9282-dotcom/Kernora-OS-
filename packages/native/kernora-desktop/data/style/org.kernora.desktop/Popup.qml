/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.desktop as Desktop
import "impl"

Desktop.Popup {
    id: control

    transformOrigin: Item.Center

    enter: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "scale"
                from: 0.94
                to: 1
                duration: M3.motionScale > 0 ? M3.durationMedium2 : 0
                easing.type: Easing.Bezier
                easing.bezierCurve: M3.easingEmphasizedDecelerate
            }
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: M3.motionScale > 0 ? M3.durationShort4 : 0
            }
        }
    }

    exit: Transition {
        NumberAnimation {
            property: "opacity"
            to: 0
            duration: M3.motionScale > 0 ? M3.durationShort3 : 0
            easing.type: Easing.Bezier
            easing.bezierCurve: M3.easingEmphasizedAccelerate
        }
    }

    background: Kirigami.ShadowedRectangle {
        radius: M3.cornerMenu
        color: Kirigami.Theme.backgroundColor
        border.width: 1
        border.color: M3.withAlpha(M3.outlineVariant, 0.6)
        shadow.xOffset: 0
        shadow.yOffset: 3
        shadow.size: 14
        shadow.color: Qt.rgba(0, 0, 0, M3.dark ? 0.45 : 0.18)
    }
}
