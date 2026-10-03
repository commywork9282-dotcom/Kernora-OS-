/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Shapes
import QtQuick.Templates as T
import org.kde.kirigami as Kirigami
import "impl"

T.BusyIndicator {
    id: control

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)
    padding: 0
    hoverEnabled: false

    contentItem: Item {
        id: spinner

        implicitWidth: Kirigami.Units.gridUnit * 2
        implicitHeight: Kirigami.Units.gridUnit * 2

        readonly property real size: Math.min(width, height)
        readonly property real stroke: Math.max(2, Math.round(size / 10))
        readonly property bool active: visible && Window.visibility !== Window.Hidden
                                       && Kirigami.Units.longDuration > 1

        visible: control.running || fade.running
        opacity: control.running ? 1 : 0
        Behavior on opacity {
            OpacityAnimator {
                id: fade
                duration: M3.durationShort4
            }
        }

        property real sweep: 90
        property real head: 0

        SequentialAnimation on sweep {
            running: spinner.active
            loops: Animation.Infinite
            NumberAnimation {
                from: 10
                to: 270
                duration: 667
                easing.type: Easing.Bezier
                easing.bezierCurve: [0.4, 0, 0.2, 1, 1, 1]
            }
            NumberAnimation {
                from: 270
                to: 10
                duration: 667
                easing.type: Easing.Bezier
                easing.bezierCurve: [0.4, 0, 0.2, 1, 1, 1]
            }
        }
        NumberAnimation on head {
            running: spinner.active
            loops: Animation.Infinite
            from: 0
            to: 1080
            duration: 4000
        }

        Shape {
            anchors.centerIn: parent
            width: spinner.size
            height: spinner.size
            preferredRendererType: Shape.CurveRenderer
            rotation: spinner.head

            ShapePath {
                strokeColor: M3.primary
                strokeWidth: spinner.stroke
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: spinner.size / 2
                    centerY: spinner.size / 2
                    radiusX: (spinner.size - spinner.stroke) / 2
                    radiusY: (spinner.size - spinner.stroke) / 2
                    startAngle: -90 - spinner.sweep / 2
                    sweepAngle: spinner.sweep
                }
            }
        }
    }
}
