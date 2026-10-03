/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import "materialshapes.js" as MaterialShapes
import "palette.js" as Palette

Item {
    id: scene

    property real phase: 0
    property real intro: 1
    readonly property real loopSeconds: 160

    readonly property real tau: 2 * Math.PI
    readonly property real beat: (phase + 0.9) % 1
    readonly property real unit: Math.min(height, width * 0.625)
    readonly property real cx: width * (width > height ? 0.58 : 0.5)
    readonly property real cy: height * 0.5

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

    readonly property var spectrum: ["rose", "ember", "amber", "mint", "teal", "sky", "violet"]
    function hue(position: real): string {
        return spectrum[Math.floor(((position % 1) + 1) % 1 * spectrum.length)];
    }

    readonly property var rings: [
        { count: 24, radius: 0.30, swing: 0.11, beats: 30, size: 0.06, tone: 78,
          shapes: ["cookie4", "clover4", "sunny", "circle", "cookie6", "softBurst"] },
        { count: 12, radius: 0.135, swing: 0.045, beats: 18, size: 0.038, tone: 66,
          shapes: ["circle", "cookie4"] }
    ]

    readonly property var positions: rings.map(ring => {
        const list = [];
        for (let i = 0; i < ring.count; ++i) {
            const angle = tau * i / ring.count - Math.PI / 2;
            const swing = Math.cos(tau * beat * (ring.beats + i));
            const r = (ring.radius + ring.swing * swing) * unit * intro;
            list.push({ x: cx + Math.cos(angle) * r, y: cy + Math.sin(angle) * r, angle: angle, swing: swing });
        }
        return list;
    })

    function blob(points: var, out: real): string {
        const n = points.length;
        if (n < 3) {
            return "";
        }
        const p = points.map(q => {
            const dx = q.x - cx, dy = q.y - cy, d = Math.max(1, Math.hypot(dx, dy));
            return { x: q.x + dx / d * out, y: q.y + dy / d * out };
        });
        let d = "M " + p[0].x + " " + p[0].y;
        for (let i = 0; i < n; ++i) {
            const p0 = p[(i - 1 + n) % n], p1 = p[i], p2 = p[(i + 1) % n], p3 = p[(i + 2) % n];
            d += " C " + (p1.x + (p2.x - p0.x) / 6) + " " + (p1.y + (p2.y - p0.y) / 6)
               + " " + (p2.x - (p3.x - p1.x) / 6) + " " + (p2.y - (p3.y - p1.y) / 6)
               + " " + p2.x + " " + p2.y;
        }
        return d + " Z";
    }

    Rectangle {
        anchors.fill: parent
        color: Palette.c("night", 8)
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            strokeColor: "transparent"
            fillColor: Palette.c("night", 17)
            PathSvg {
                path: scene.width > 0 ? scene.blob(scene.positions[0], scene.unit * 0.02) : ""
            }
        }
        ShapePath {
            strokeWidth: -1
            strokeColor: "transparent"
            fillColor: Palette.c("night", 25)
            PathSvg {
                path: scene.width > 0 ? scene.blob(scene.positions[1], scene.unit * 0.012) : ""
            }
        }
    }

    MaterialShape {
        shape: "cookie9"
        colour: Palette.c("night", 32)
        size: scene.unit * 0.13 * scene.intro
        x: scene.cx - width / 2
        y: scene.cy - height / 2
        rotation: -360 * scene.phase
    }
    MaterialShape {
        shape: "sunny"
        colour: Palette.c("ember", 64)
        size: scene.unit * 0.06 * scene.intro
        x: scene.cx - width / 2
        y: scene.cy - height / 2
        rotation: 720 * scene.phase
    }

    Repeater {
        model: scene.rings
        delegate: Item {
            id: ring
            required property var modelData
            required property int index
            anchors.fill: parent

            Repeater {
                model: ring.modelData.count
                delegate: MaterialShape {
                    id: bob
                    required property int index
                    readonly property var place: scene.positions[ring.index][index]

                    shape: ring.modelData.shapes[index % ring.modelData.shapes.length]
                    colour: Palette.c(scene.hue(index / ring.modelData.count + ring.index * 0.5), ring.modelData.tone)
                    size: ring.modelData.size * scene.unit * (1 + 0.22 * place.swing)
                    x: place.x - width / 2
                    y: place.y - height / 2
                    rotation: place.angle * 180 / Math.PI + 90 + 360 * scene.phase * (index % 2 === 0 ? 2 : -2)
                }
            }
        }
    }
}
