/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import "materialshapes.js" as MaterialShapes
import org.kernora.m3

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
    readonly property real loopSeconds: 120

    readonly property real tau: 2 * Math.PI
    readonly property real unit: Math.min(width, height)
    readonly property bool portrait: height > width

    function wave(cycles: int, offset: real): real {
        return Math.sin(scene.tau * (scene.phase * cycles + offset));
    }

    component Figure: Item {
        id: figure

        property string shape: "circle"
        property color colour: "white"
        property real size: 100
        property real cx: 0
        property real cy: 0
        property real angle: 0

        x: cx - size / 2
        y: cy - size / 2
        width: size
        height: size
        rotation: angle

        Shape {
            width: MaterialShapes.units
            height: MaterialShapes.units
            scale: figure.size / MaterialShapes.units
            transformOrigin: Item.TopLeft
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: -1
                strokeColor: "transparent"
                fillColor: figure.colour
                PathSvg {
                    path: MaterialShapes.shapes[figure.shape].path
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: scene.c("base", 65)
    }

    Shape {
        id: hill

        width: 1000
        height: 1000
        preferredRendererType: Shape.CurveRenderer
        transform: Scale {
            xScale: scene.width / 1000
            yScale: scene.height / 1000
        }

        readonly property real swell: 14 * scene.wave(2, 0.1)

        ShapePath {
            strokeWidth: -1
            strokeColor: "transparent"
            fillColor: scene.c("light", 86)
            startX: 0
            startY: scene.portrait ? 230 : 330

            PathCubic {
                control1X: 70; control1Y: scene.portrait ? 270 : 360
                control2X: 120; control2Y: scene.portrait ? 330 : 455 + hill.swell * 0.5
                x: 230; y: (scene.portrait ? 355 : 490) + hill.swell * 0.5
            }
            PathCubic {
                control1X: 330; control1Y: (scene.portrait ? 378 : 522) + hill.swell * 0.5
                control2X: 410; control2Y: (scene.portrait ? 330 : 500) + hill.swell
                x: 520; y: (scene.portrait ? 380 : 545) + hill.swell
            }
            PathCubic {
                control1X: 660; control1Y: (scene.portrait ? 444 : 602) + hill.swell
                control2X: scene.portrait ? 900 : 760; control2Y: scene.portrait ? 520 : 690
                x: scene.portrait ? 830 : 720; y: scene.portrait ? 640 : 850
            }
            PathCubic {
                control1X: scene.portrait ? 790 : 700; control1Y: scene.portrait ? 760 : 940
                control2X: scene.portrait ? 520 : 610; control2Y: scene.portrait ? 900 : 980
                x: scene.portrait ? 380 : 560; y: 1000
            }
            PathLine { x: 0; y: 1000 }
            PathLine { x: 0; y: scene.portrait ? 230 : 330 }
        }
    }

    Figure {
        shape: "arch"
        colour: scene.c("deep", 52)
        size: scene.unit * (scene.portrait ? 0.72 : 0.62)
        cx: scene.width * (scene.portrait ? 0.4 : 0.27) + scene.unit * 0.008 * scene.wave(1, 0.2)
        cy: scene.height * (scene.portrait ? 0.82 : 0.86)
        angle: 158 + 2.5 * scene.wave(1, 0.55)
    }

    Figure {
        shape: "circle"
        colour: scene.c("light", 86)
        size: scene.unit * (scene.portrait ? 0.7 : 0.6)
        cx: scene.width * (scene.portrait ? 0.92 : 0.9) + scene.unit * 0.01 * scene.wave(1, 0.7)
        cy: scene.height * (scene.portrait ? 0.9 : 0.95) + scene.unit * 0.008 * scene.wave(2, 0.3)
    }

    Item {
        id: cluster

        readonly property real cx: scene.width * (scene.portrait ? 0.74 : 0.73)
        readonly property real cy: scene.height * (scene.portrait ? 0.27 : 0.33)
        readonly property real s: scene.unit * (scene.portrait ? 0.95 : 0.85)

        opacity: scene.intro
        scale: 0.9 + 0.1 * scene.intro

        Rectangle {
            readonly property real cx: cluster.cx + cluster.s * (0.01 + 0.012 * scene.wave(3, 0.0))
            readonly property real cy: cluster.cy + cluster.s * (-0.16 + 0.012 * scene.wave(2, 0.25))

            x: cx - width / 2
            y: cy - height / 2
            width: cluster.s * 0.3
            height: cluster.s * 0.13
            radius: height / 2
            rotation: -40 + 6 * scene.wave(2, 0.1)
            antialiasing: true
            color: scene.c("rose", 70)
        }
        Figure {
            shape: "circle"
            colour: scene.c("light", 86)
            size: cluster.s * 0.09
            cx: cluster.cx + cluster.s * (-0.16 + 0.01 * scene.wave(4, 0.4))
            cy: cluster.cy + cluster.s * (0.03 + 0.01 * scene.wave(3, 0.8))
        }
        Figure {
            shape: "cookie12"
            colour: scene.c("amber", 86)
            size: cluster.s * 0.17
            cx: cluster.cx + cluster.s * (0.13 + 0.01 * scene.wave(2, 0.6))
            cy: cluster.cy + cluster.s * (0.04 + 0.012 * scene.wave(3, 0.1))
            angle: 360 * scene.phase
        }
        Figure {
            shape: "triangle"
            colour: scene.c("plum", 38)
            size: cluster.s * 0.12
            cx: cluster.cx + cluster.s * (-0.03 + 0.012 * scene.wave(3, 0.65))
            cy: cluster.cy + cluster.s * (0.2 + 0.01 * scene.wave(2, 0.9))
            angle: -12 + 10 * scene.wave(2, 0.35)
        }
    }
}
