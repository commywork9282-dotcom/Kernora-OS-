/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import "materialshapes.js" as MaterialShapes
import org.kernora.m3
import "tower.js" as Tower

Item {
    id: scene

    readonly property string colour: M3.colour
    Loader {
        id: paletteSource
        source: Qt.resolvedUrl("palettes/" + scene.colour + ".qml")
    }
    readonly property var colours: paletteSource.item ? paletteSource.item.palette : null

    function c(family: string, tone: real): color {
        const p = scene.colours;
        if (!p) {
            return "transparent";
        }
        let best = p.tones[0];
        for (const t of p.tones) {
            if (Math.abs(t - tone) < Math.abs(best - tone)) {
                best = t;
            }
        }
        return p.families[family][String(best)];
    }

    property real phase: 0
    property real intro: 1
    readonly property real loopSeconds: Tower.loopSeconds
    readonly property real unit: Tower.unitOf(width, height)

    property var plan: null
    function replan(): void {
        if (width > 0 && height > 0 && (!plan || plan.width !== width || plan.height !== height)) {
            plan = Tower.plan(width, height);
        }
    }
    onWidthChanged: Qt.callLater(replan)
    onHeightChanged: Qt.callLater(replan)
    Component.onCompleted: Qt.callLater(replan)
    readonly property var poses: plan ? Tower.poses(plan, phase) : []

    Rectangle {
        anchors.fill: parent
        color: scene.c("paper", 94)
    }

    Shape {
        readonly property real side: scene.unit * 1.15
        width: MaterialShapes.units
        height: MaterialShapes.units
        x: scene.width * Tower.AXIS - width / 2
        y: scene.height * 0.5 - height / 2
        scale: side / MaterialShapes.units * (0.9 + 0.1 * scene.intro)
        rotation: 12
        opacity: scene.intro
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            strokeColor: "transparent"
            fillColor: scene.c("paper", 90)
            PathSvg {
                path: MaterialShapes.shapes.cookie12.path
            }
        }
    }

    Rectangle {
        y: scene.height * Tower.FLOOR
        width: scene.width
        height: scene.height - y
        color: scene.c("paper", 86)
    }

    Repeater {
        model: Tower.pieces.length

        delegate: Item {
            id: piece

            required property int index
            readonly property var spec: Tower.pieces[index]
            readonly property var pose: scene.poses.length > index ? scene.poses[index] : null

            readonly property real bloom: {
                const t = Math.max(0, Math.min(1, (scene.intro - index * 0.06) / 0.5));
                const c = 1.4;
                return t >= 1 ? 1 : 1 + (c + 1) * Math.pow(t - 1, 3) + c * Math.pow(t - 1, 2);
            }

            width: spec.w * Tower.SCALE * scene.unit
            height: spec.h * Tower.SCALE * scene.unit
            visible: pose !== null && bloom > 0
            x: pose ? pose.x - width / 2 : 0
            y: pose ? pose.y - height / 2 : 0
            rotation: pose ? pose.a : 0
            scale: bloom

            Item {
                anchors.fill: parent
                transform: Scale {
                    origin.x: piece.width / 2
                    origin.y: piece.height
                    xScale: piece.pose ? piece.pose.sx : 1
                    yScale: piece.pose ? piece.pose.sy : 1
                }

                Rectangle {
                    visible: piece.spec.shape === "slab"
                    anchors.fill: parent
                    radius: height / 2
                    color: scene.c(piece.spec.family, piece.spec.tone)
                }
                Shape {
                    visible: piece.spec.shape !== "slab"
                    width: MaterialShapes.units
                    height: MaterialShapes.units
                    transform: Scale {
                        xScale: piece.width / MaterialShapes.units
                        yScale: piece.height / MaterialShapes.units
                    }
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeWidth: -1
                        strokeColor: "transparent"
                        fillColor: scene.c(piece.spec.family, piece.spec.tone)
                        PathSvg {
                            path: piece.spec.shape === "slab" ? "" : MaterialShapes.shapes[piece.spec.shape].path
                        }
                    }
                }
            }
        }
    }
}
