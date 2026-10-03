/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import "materialshapes.js" as MaterialShapes
import "palette.js" as Palette
import "run.js" as Run

Item {
    id: scene

    property real phase: 0
    property real intro: 1
    readonly property real loopSeconds: Run.loopSeconds
    readonly property real unit: Run.unitOf(width, height)

    property var plan: null
    function replan(): void {
        if (width > 0 && height > 0 && (!plan || plan.width !== width || plan.height !== height)) {
            plan = Run.plan(width, height);
        }
    }
    onWidthChanged: Qt.callLater(replan)
    onHeightChanged: Qt.callLater(replan)
    Component.onCompleted: Qt.callLater(replan)

    readonly property var poses: plan ? Run.poses(plan, phase) : []
    readonly property var nods: plan ? Run.nods(plan, phase) : []

    component MaterialShape: Shape {
        id: ms
        property string shape: "circle"
        property color colour: "white"
        property real size: 100
        width: MaterialShapes.units
        height: MaterialShapes.units
        scale: size / MaterialShapes.units
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            strokeColor: "transparent"
            fillColor: ms.colour
            PathSvg {
                path: MaterialShapes.shapes[ms.shape].path
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Palette.c("board", 18)
    }

    MaterialShape {
        shape: "flower"
        colour: Palette.c("board", 21)
        size: scene.height * 1.0
        x: -scene.height * 0.25 - width / 2 + size / 2
        y: scene.height * 0.62 - height / 2
        rotation: 10
        opacity: scene.intro
    }
    MaterialShape {
        shape: "cookie9"
        colour: Palette.c("board", 21)
        size: scene.height * 0.5
        x: scene.width * 0.3 - width / 2
        y: scene.height * 0.06 - height / 2
        rotation: -8
        opacity: scene.intro
    }

    Item {
        anchors.fill: parent
        visible: scene.plan !== null
        opacity: Math.min(1, scene.intro * 1.5)

        readonly property real wall: scene.unit * 0.014
        readonly property real slotTop: scene.plan ? scene.plan.rideTo[1] - scene.plan.radius * 1.2 : 0
        readonly property real slotBottom: scene.plan ? scene.plan.rideFrom[1] + scene.plan.radius + scene.unit * 0.035 : 0

        Rectangle {
            id: frame
            readonly property var lift: scene.plan ? scene.plan.lift : null
            x: lift ? lift.x - lift.width / 2 - parent.wall : 0
            y: lift ? lift.top - parent.wall : 0
            width: lift ? lift.width + parent.wall * 2 : 0
            height: lift ? lift.bottom - lift.top + parent.wall * 2 : 0
            radius: width / 2
            color: Palette.c("cream", 84)
        }
        Rectangle {
            x: frame.x + parent.wall
            y: parent.slotTop
            width: frame.width - parent.wall * 2
            height: parent.slotBottom - parent.slotTop
            color: Palette.c("board", 12)
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.max(2, parent.width * 0.05)
                height: parent.height
                color: Palette.c("board", 26)
            }
        }

        Item {
            x: frame.x + parent.wall
            y: parent.slotTop
            width: frame.width - parent.wall * 2
            height: parent.slotBottom - parent.slotTop
            clip: true

            Repeater {
                model: Run.MARBLES
                delegate: Rectangle {
                    required property int index
                    readonly property var pose: scene.poses.length > index ? scene.poses[index] : null
                    visible: pose !== null && pose.cup !== null
                    width: scene.plan ? scene.plan.lift.width * 0.78 : 0
                    height: scene.unit * 0.022
                    radius: height / 2
                    x: scene.plan ? scene.plan.lift.x - width / 2 - parent.x : 0
                    y: pose && pose.cup !== null ? pose.cup - parent.y : 0
                    color: Palette.c("cream", 84)
                }
            }
        }

        Repeater {
            model: scene.plan ? scene.plan.ramps : []
            delegate: Item {
                id: ramp
                required property var modelData
                required property int index
                readonly property real thickness: scene.unit * 0.032

                Rectangle {
                    readonly property real cx: (ramp.modelData.a[0] + ramp.modelData.b[0]) / 2 - ramp.modelData.normal[0] * ramp.thickness / 2
                    readonly property real cy: (ramp.modelData.a[1] + ramp.modelData.b[1]) / 2 - ramp.modelData.normal[1] * ramp.thickness / 2
                    width: ramp.modelData.length + ramp.thickness
                    height: ramp.thickness
                    radius: height / 2
                    x: cx - width / 2
                    y: cy - height / 2
                    rotation: ramp.modelData.angle + (ramp.modelData.b[0] < ramp.modelData.a[0] ? 180 : 0)
                    color: Palette.c("track", 70)
                }

                Rectangle {
                    visible: ramp.modelData.post !== null
                    readonly property real r: scene.plan ? scene.plan.postRadius : 0
                    x: ramp.modelData.post ? ramp.modelData.post.x - r : 0
                    y: ramp.modelData.post ? ramp.modelData.post.top : 0
                    width: r * 2
                    height: ramp.modelData.post ? ramp.modelData.a[1] - ramp.modelData.post.top + ramp.thickness * 0.5 : 0
                    radius: r
                    color: Palette.c("track", 58)
                }
                MaterialShape {
                    visible: ramp.modelData.post !== null
                    shape: "sunny"
                    colour: Palette.c("amber", 80)
                    size: scene.unit * 0.065
                    x: ramp.modelData.post ? ramp.modelData.post.x - width / 2 : 0
                    y: ramp.modelData.post ? ramp.modelData.post.top - height / 2 : 0
                    rotation: scene.nods.length > ramp.index ? scene.nods[ramp.index] : 0
                    scale: size / MaterialShapes.units * (1 + Math.abs(scene.nods.length > ramp.index ? scene.nods[ramp.index] : 0) / 120)
                }
            }
        }

        Repeater {
            model: Run.MARBLES
            delegate: MaterialShape {
                required property int index
                readonly property var spec: Run.marbles[index]
                readonly property var pose: scene.poses.length > index ? scene.poses[index] : null
                visible: pose !== null
                shape: spec.shape
                colour: Palette.c(spec.family, spec.tone)
                size: scene.plan ? scene.plan.radius / MaterialShapes.shapes[spec.shape].radius * scene.intro : 0
                x: pose ? pose.x - width / 2 : 0
                y: pose ? pose.y - height / 2 : 0
                rotation: pose ? pose.a : 0
            }
        }
    }
}
