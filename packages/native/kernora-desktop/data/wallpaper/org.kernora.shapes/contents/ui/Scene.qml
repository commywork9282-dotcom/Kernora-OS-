/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import "materialshapes.js" as MaterialShapes
import "palette.js" as Palette
import "choreography.js" as Choreography

Item {
    id: scene

    property real phase: 0
    property real intro: 1
    property bool colourCycle: true

    readonly property int samples: 720
    readonly property int sample: Math.floor(scene.phase * samples) % samples
    readonly property real sampledPhase: sample / samples

    property var zTable: []

    function reschedule(): void {
        if (width > 0 && height > 0) {
            zTable = Choreography.schedule(width, height, samples);
        }
    }

    onWidthChanged: rescheduleTimer.restart()
    onHeightChanged: rescheduleTimer.restart()
    Component.onCompleted: reschedule()

    Timer {
        id: rescheduleTimer
        interval: 250
        onTriggered: scene.reschedule()
    }

    Rectangle {
        anchors.fill: parent
        color: Palette.palette.background
    }

    Repeater {
        model: Choreography.cast.length

        delegate: Shape {
            id: shape

            required property int index
            readonly property var spec: Choreography.cast[index]
            readonly property point centre: Choreography.position(spec, scene.phase, scene.width, scene.height)

            readonly property real delay: index * 0.06
            readonly property real bloom: {
                const t = Math.max(0, Math.min(1, (scene.intro - delay) / (1 - 0.66)));
                const c = 1.4;
                return t >= 1 ? 1 : 1 + (c + 1) * Math.pow(t - 1, 3) + c * Math.pow(t - 1, 2);
            }

            readonly property real side: MaterialShapes.units
            width: side
            height: side
            x: centre.x - side / 2
            y: centre.y - side / 2
            scale: spec.size * scene.height / side * Choreography.breath(spec, scene.phase) * bloom
            rotation: Choreography.rotation(spec, scene.phase, index) - 40 * (1 - bloom)
            opacity: Math.min(1, bloom * 2)
            visible: bloom > 0
            z: scene.zTable.length > 0 ? scene.zTable[scene.sample][index] : index

            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: -1
                strokeColor: "transparent"
                fillColor: Choreography.colour(shape.spec, scene.sampledPhase, scene.colourCycle)
                PathSvg {
                    path: MaterialShapes.shapes[shape.spec.shape].path
                }
            }
        }
    }
}
