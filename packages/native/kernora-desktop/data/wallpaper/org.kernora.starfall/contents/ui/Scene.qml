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
    readonly property real loopSeconds: 90

    readonly property real tau: 2 * Math.PI
    readonly property real unit: Math.min(width, height)
    readonly property real dot: Math.max(1, unit / 900)

    function sequence(seed: int): var {
        let state = seed >>> 0;
        return () => {
            state = (state + 0x6D2B79F5) >>> 0;
            let t = state;
            t = Math.imul(t ^ (t >>> 15), t | 1);
            t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
            return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
        };
    }

    readonly property var stars: {
        const next = sequence(2026);
        const list = [];
        for (let i = 0; i < 170; ++i) {
            list.push({
                x: next(),
                y: Math.pow(next(), 1.4) * 0.86,
                size: 0.8 + next() * next() * 2.4,
                tone: 84 + Math.round(next() * 14),
                family: next() < 0.35 ? "frost" : "star",
                cycles: 18 + Math.floor(next() * 36),
                offset: next(),
                depth: 0.25 + next() * 0.45
            });
        }
        return list;
    }

    readonly property var sparkles: [
        { x: 0.16, y: 0.16, size: 0.022, shape: "softBurst", cycles: 11, offset: 0.1 },
        { x: 0.42, y: 0.08, size: 0.016, shape: "sunny", cycles: 15, offset: 0.6 },
        { x: 0.71, y: 0.22, size: 0.026, shape: "softBurst", cycles: 9, offset: 0.35 },
        { x: 0.88, y: 0.1, size: 0.014, shape: "sunny", cycles: 17, offset: 0.8 },
        { x: 0.3, y: 0.34, size: 0.012, shape: "softBurst", cycles: 13, offset: 0.25 },
        { x: 0.58, y: 0.42, size: 0.015, shape: "sunny", cycles: 19, offset: 0.5 }
    ]

    readonly property var meteors: {
        const next = sequence(77);
        const count = 14;
        const list = [];
        for (let i = 0; i < count; ++i) {
            const duration = 1.2 + next() * 0.9;
            list.push({
                start: i === 0 ? 0.3 - 0.45 * duration / scene.loopSeconds : (i + 0.2 + next() * 0.6) / count,
                duration: duration / scene.loopSeconds,
                x: 0.3 + next() * 0.65,
                y: 0.02 + next() * 0.3,
                angle: 146 + next() * 18,
                travel: 0.32 + next() * 0.28,
                length: 0.14 + next() * 0.12
            });
        }
        return list;
    }

    component MaterialShape: Shape {
        id: ms
        property string shape: "circle"
        property color colour: "white"
        property real size: 100
        width: MaterialShapes.units
        height: MaterialShapes.units
        scale: size / MaterialShapes.units
        transformOrigin: Item.TopLeft
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

    opacity: intro

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: scene.c("night", 4) }
            GradientStop { position: 0.45; color: scene.c("night", 8) }
            GradientStop { position: 0.7; color: scene.c("night", 14) }
            GradientStop { position: 0.84; color: scene.c("glow", 22) }
            GradientStop { position: 1.0; color: scene.c("glow", 34) }
        }
    }

    Repeater {
        model: scene.stars

        delegate: Rectangle {
            id: star

            required property var modelData
            readonly property real twinkle: 0.5 + 0.5 * Math.sin(scene.tau * (scene.phase * modelData.cycles + modelData.offset))

            x: modelData.x * scene.width - width / 2
            y: modelData.y * scene.height - height / 2
            width: modelData.size * scene.dot
            height: width
            radius: width / 2
            color: scene.c(modelData.family, modelData.tone)
            opacity: 1 - modelData.depth * star.twinkle
        }
    }

    Repeater {
        model: scene.sparkles

        delegate: Item {
            id: sparkle

            required property var modelData
            readonly property real side: modelData.size * scene.unit
            readonly property real twinkle: 0.5 + 0.5 * Math.sin(scene.tau * (scene.phase * modelData.cycles + modelData.offset))

            x: modelData.x * scene.width - side / 2
            y: modelData.y * scene.height - side / 2
            width: side
            height: side
            rotation: 360 * scene.phase * (modelData.cycles % 2 === 0 ? 2 : -2)
            scale: 0.8 + 0.25 * twinkle
            opacity: 0.65 + 0.35 * twinkle

            Shape {
                id: halo
                anchors.centerIn: parent
                width: sparkle.side * 3.2
                height: width
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: -1
                    strokeColor: "transparent"
                    fillGradient: RadialGradient {
                        centerX: halo.width / 2
                        centerY: halo.height / 2
                        centerRadius: halo.width / 2
                        focalX: centerX
                        focalY: centerY
                        GradientStop { position: 0.0; color: M3.withAlpha(scene.c("star", 94), 0.32) }
                        GradientStop { position: 0.45; color: M3.withAlpha(scene.c("frost", 80), 0.08) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                    PathAngleArc {
                        centerX: halo.width / 2
                        centerY: halo.height / 2
                        radiusX: halo.width / 2
                        radiusY: halo.height / 2
                        sweepAngle: 360
                    }
                }
            }
            MaterialShape {
                shape: sparkle.modelData.shape
                size: sparkle.side
                colour: scene.c("star", 96)
            }
        }
    }

    Repeater {
        model: scene.meteors

        delegate: Item {
            id: meteor

            required property var modelData
            readonly property real progress: {
                const elapsed = ((scene.phase - modelData.start) % 1 + 1) % 1;
                return elapsed / modelData.duration;
            }
            readonly property bool flying: progress >= 0 && progress <= 1
            readonly property real eased: progress * progress * (1.6 - 0.6 * progress)
            readonly property real radians: modelData.angle * Math.PI / 180
            readonly property real distance: modelData.travel * scene.unit * eased
            readonly property real trail: modelData.length * scene.unit * Math.sin(Math.PI * Math.min(1, progress * 1.15))

            visible: flying
            x: modelData.x * scene.width + Math.cos(radians) * distance
            y: modelData.y * scene.height + Math.sin(radians) * distance
            rotation: modelData.angle
            opacity: Math.min(1, (1 - progress) * 4) * Math.min(1, progress * 8)

            Rectangle {
                x: -meteor.trail
                y: -height / 2
                width: meteor.trail
                height: 2.2 * scene.dot
                radius: height / 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.75; color: M3.withAlpha(scene.c("meteor", 80), 0.55) }
                    GradientStop { position: 1.0; color: scene.c("star", 96) }
                }
            }
            Rectangle {
                x: -width / 2
                y: -height / 2
                width: 9 * scene.dot
                height: width
                radius: width / 2
                color: scene.c("meteor", 90)
                opacity: 0.35
            }
            Rectangle {
                x: -width / 2
                y: -height / 2
                width: 3.6 * scene.dot
                height: width
                radius: width / 2
                color: scene.c("star", 98)
            }
        }
    }

    MaterialShape {
        shape: "arch"
        size: scene.width * 1.1
        x: -scene.width * 0.38
        y: scene.height - size * 0.14
        colour: scene.c("hill", 6)
    }
    MaterialShape {
        shape: "puffy"
        size: scene.width * 1.25
        x: scene.width * 0.36
        y: scene.height - size * 0.16
        colour: scene.c("hill", 5)
    }
    MaterialShape {
        shape: "cookie9"
        size: scene.width * 0.75
        x: scene.width * 0.3
        y: scene.height - size * 0.12
        colour: scene.c("hill", 4)
    }
}
