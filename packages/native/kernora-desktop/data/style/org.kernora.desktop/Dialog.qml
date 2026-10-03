/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Templates as T
import org.kde.kirigami as Kirigami
import org.kde.desktop as Desktop
import "impl"

Desktop.Dialog {
    id: control

    padding: 24
    transformOrigin: Item.Center

    T.Overlay.modal: Rectangle {
        color: M3.withAlpha(M3.scrim, 0.32)
        Behavior on opacity {
            enabled: M3.motionScale > 0
            OpacityAnimator {
                duration: M3.durationMedium2
                easing.type: Easing.Bezier
                easing.bezierCurve: M3.easingStandard
            }
        }
    }

    enter: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "scale"
                from: 0.9
                to: 1
                duration: M3.motionScale > 0 ? M3.durationMedium4 : 0
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
            duration: M3.motionScale > 0 ? M3.durationShort4 : 0
            easing.type: Easing.Bezier
            easing.bezierCurve: M3.easingEmphasizedAccelerate
        }
    }

    background: Kirigami.ShadowedRectangle {
        color: M3.surfaceContainerHigh
        readonly property var shadowSpec: M3.elevationOf("dialog")
        radius: M3.cornerDialog
        shadow.size: M3.classic ? shadowSpec.blur : 24
        shadow.yOffset: M3.classic ? shadowSpec.offset : 6
        shadow.color: Qt.rgba(0, 0, 0, M3.classic ? shadowSpec.opacity : M3.dark ? 0.5 : 0.2)
    }

    header: Kirigami.Heading {
        text: control.title
        level: 1
        visible: control.title
        elide: Text.ElideRight
        color: M3.surfaceContent
        padding: 24
        bottomPadding: 0
    }
}
