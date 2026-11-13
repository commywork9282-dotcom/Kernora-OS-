/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.layershell as LayerShell
import "m3"

Window {
    id: bar

    required property int percent

    readonly property color tint: percent < 20 ? "#f28b82" : percent < 60 ? "#fdd663" : "#3ddc84"
    readonly property real level: Math.max(0.04, Math.min(1, percent / 100))
    property real progress: 0
    property real glow: 0

    LayerShell.Window.scope: "on-screen-display"
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone

    flags: Qt.FramelessWindowHint | Qt.WindowTransparentForInput | Qt.WindowDoesNotAcceptFocus
    color: "transparent"
    title: "Glowbar"
    width: screen ? screen.width : 1920
    height: 32
    visible: true

    Item {
        anchors.fill: parent
        opacity: bar.glow

        Rectangle {
            width: line.width
            height: parent.height
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha(bar.tint, 0.55) }
                GradientStop { position: 0.35; color: Qt.alpha(bar.tint, 0.18) }
                GradientStop { position: 1; color: Qt.alpha(bar.tint, 0) }
            }
        }

        Rectangle {
            id: line
            width: Math.round(bar.width * bar.level * bar.progress)
            height: 4
            topRightRadius: 0
            bottomRightRadius: 2
            color: bar.tint

            Rectangle {
                anchors.right: parent.right
                width: Math.min(parent.width, 96)
                height: parent.height
                bottomRightRadius: 2
                opacity: 1 - bar.progress * 0.6
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Qt.alpha("white", 0) }
                    GradientStop { position: 1; color: Qt.alpha("white", 0.85) }
                }
            }
        }
    }

    SequentialAnimation {
        running: true
        ParallelAnimation {
            NumberAnimation {
                target: bar
                property: "glow"
                from: 0
                to: 1
                duration: M3.durationShort4
            }
            NumberAnimation {
                target: bar
                property: "progress"
                from: M3.motionScale > 0 ? 0 : 1
                to: 1
                duration: 1100 * M3.motionScale
                easing.type: Easing.Bezier
                easing.bezierCurve: M3.easingEmphasizedDecelerate
            }
        }
        PauseAnimation {
            duration: 1000
        }
        NumberAnimation {
            target: bar
            property: "glow"
            to: 0
            duration: M3.durationLong2
            easing.type: Easing.Bezier
            easing.bezierCurve: M3.easingEmphasizedAccelerate
        }
        ScriptAction {
            script: bar.destroy()
        }
    }
}
