/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import "morphs.js" as Morphs
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
    readonly property real loopSeconds: 224

    readonly property real tau: 2 * Math.PI
    readonly property real unit: Math.min(width * 1.35, height)
    readonly property int kinds: Morphs.names.length
    readonly property real stream: scene.phase * scene.kinds
    readonly property real figure: scene.unit * 0.25
    readonly property real margin: scene.width > 0 ? 0.62 * scene.figure / scene.width + 0.01 : 0.1
    readonly property int count: Math.max(3, Math.round((1 + 2 * scene.margin) * scene.width / (scene.figure * 1.2)))
    readonly property real waist: 0.52 + 0.03 * scene.wave(1, 0.15)
    readonly property real breath: 1 + 0.05 * scene.wave(2, 0.4)
    readonly property real opening: 1 - Math.pow(1 - scene.intro, 3)
    readonly property var tints: [["soft", 80], ["light", 92], ["soft", 80], ["accent", 85]]

    function wave(cycles: int, offset: real): real {
        return Math.sin(scene.tau * (scene.phase * cycles + offset));
    }

    function spring(f: real): real {
        const g = f - 1;
        return 1 + 3.2 * g * g * g + 2.2 * g * g;
    }

    function centre(t: real): real {
        return scene.height * 0.5 + scene.unit * (0.06 * (t - 0.5) - 0.035 * Math.sin(Math.PI * t)
                                                  + 0.016 * Math.sin(scene.tau * (1.1 * t - 6 * scene.phase)));
    }

    function thickness(t: real): real {
        const d = t - scene.waist;
        return scene.unit * scene.breath * (0.19 + 0.42 * d * d);
    }

    function tint(slot: int): color {
        const entry = scene.tints[slot % scene.tints.length];
        return scene.c(entry[0], entry[1]);
    }

    function mix(a: color, b: color, f: real): color {
        return Qt.rgba(a.r + (b.r - a.r) * f, a.g + (b.g - a.g) * f, a.b + (b.b - a.b) * f, 1);
    }

    function outline(from: int, to: int, f: real): var {
        const a = Morphs.shapes[from];
        const b = Morphs.shapes[to];
        const n = Morphs.samples;
        const points = [];
        for (let k = 0; k <= n; ++k) {
            const i = k % n;
            const r = 1000 * Math.max(0, a[i] + (b[i] - a[i]) * f);
            const angle = scene.tau * i / n;
            points.push(Qt.point(500 + r * Math.cos(angle), 500 + r * Math.sin(angle)));
        }
        return points;
    }

    readonly property var band: {
        const points = [];
        const steps = 48;
        const open = 0.12 + 0.88 * scene.opening;
        for (let i = 0; i <= steps; ++i) {
            const t = -0.02 + 1.04 * i / steps;
            points.push(Qt.point(t * scene.width, scene.centre(t) - scene.thickness(t) * open));
        }
        for (let i = steps; i >= 0; --i) {
            const t = -0.02 + 1.04 * i / steps;
            points.push(Qt.point(t * scene.width, scene.centre(t) + scene.thickness(t) * open));
        }
        points.push(points[0]);
        return points;
    }

    Rectangle {
        anchors.fill: parent
        color: scene.c("base", 65)
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            strokeColor: "transparent"
            fillColor: scene.c("band", 46)
            PathPolyline {
                path: scene.band
            }
        }
    }

    Repeater {
        model: scene.count + 1

        delegate: Item {
            id: figure

            required property int index
            readonly property int item: Math.floor(scene.stream) - index
            readonly property int slot: (item % scene.kinds + scene.kinds) % scene.kinds
            readonly property real u: (scene.stream - item) / scene.count
            readonly property real t: (1 + 2 * scene.margin) * u - scene.margin
            readonly property real passage: Math.max(0, Math.min(1, (t - scene.waist) / 0.05 + 0.5))
            readonly property real morph: scene.spring(passage)
            readonly property int from: 5 * slot % scene.kinds
            readonly property int to: (5 * slot + 1) % scene.kinds
            readonly property real pop: scene.spring(Math.max(0, Math.min(1, scene.intro * 1.8 - u * 0.8)))
            readonly property real size: scene.figure * pop * (1 - 0.14 * Math.sin(Math.PI * passage))
                                         * (0.82 + 0.18 * Math.min(1, scene.thickness(t) / (scene.unit * 0.3)))
            readonly property color colour: scene.mix(scene.tint(slot), scene.tint(slot + 1), passage)
            readonly property var outline: scene.outline(from, to, morph)

            visible: t < 1 + scene.margin
            x: t * scene.width - 500
            y: scene.centre(t) + scene.unit * 0.012 * Math.sin(scene.tau * (2 * u + 0.31 * slot)) - 500
            width: 1000
            height: 1000
            scale: size / 1000
            rotation: (slot % 2 ? 100 : -100) * u + 90 * morph

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: -1
                    strokeColor: "transparent"
                    fillColor: figure.colour
                    PathPolyline {
                        path: figure.outline
                    }
                }
            }
        }
    }
}
