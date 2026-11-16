/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Shapes
import "materialshapes.js" as MaterialShapes

Item {
    id: glyph

    property string kind: "clear"
    property bool day: true

    readonly property real unit: Math.min(width, height) / 100
    readonly property bool hasSun: kind === "clear" || kind === "mostly" || kind === "partly"
    readonly property bool hasCloud: kind !== "clear" && kind !== "fog"

    component Sun: Item {
        id: sun

        property real unit: 1
        property real boxX
        property real boxY
        property real boxSize

        x: boxX * unit
        y: boxY * unit
        width: boxSize * unit
        height: width

        Shape {
            width: MaterialShapes.units
            height: MaterialShapes.units
            scale: sun.width / MaterialShapes.units
            transformOrigin: Item.TopLeft
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: -1
                strokeColor: "transparent"
                fillGradient: LinearGradient {
                    x1: 220
                    y1: 160
                    x2: 860
                    y2: 900
                    GradientStop {
                        position: 0
                        color: "#ffdd4d"
                    }
                    GradientStop {
                        position: 0.55
                        color: "#ffd22e"
                    }
                    GradientStop {
                        position: 1
                        color: "#f3b11f"
                    }
                }
                PathSvg {
                    path: MaterialShapes.shapes.sunny.path
                }
            }
        }
    }

    component Moon: Shape {
        id: moon

        property real unit: 1
        property real boxX
        property real boxY
        property real boxSize

        x: boxX * unit
        y: boxY * unit
        width: 100
        height: 100
        scale: boxSize * unit / 100
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 20
                y1: 10
                x2: 80
                y2: 95
                GradientStop {
                    position: 0
                    color: "#f4f1fc"
                }
                GradientStop {
                    position: 1
                    color: "#c6c1e3"
                }
            }
            PathSvg {
                path: "M 48.03 6.05 A 44 44 0 1 0 92.11 62.71 A 36 36 0 1 1 48.03 6.05 Z"
            }
        }
    }

    component Cloud: Shape {
        id: cloud

        property real unit: 1
        property real boxX
        property real boxY
        property real boxWidth
        property color light: "#faf7ef"
        property color shade: "#d3d0c6"

        x: boxX * unit
        y: boxY * unit
        width: 100
        height: 62
        scale: boxWidth * unit / 100
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 30
                y1: 6
                x2: 78
                y2: 64
                GradientStop {
                    position: 0
                    color: cloud.light
                }
                GradientStop {
                    position: 0.62
                    color: Qt.tint(cloud.light, Qt.rgba(cloud.shade.r, cloud.shade.g, cloud.shade.b, 0.35))
                }
                GradientStop {
                    position: 1
                    color: cloud.shade
                }
            }
            PathSvg {
                path: "M 20 62 L 76 62 A 22 22 0 1 0 71.67 18.44 A 30 30 0 0 0 14.15 26.96 A 18 18 0 0 0 20 62 Z"
            }
        }
    }

    component Drop: Rectangle {
        property real unit: 1
        property real boxX
        property real boxY

        x: boxX * unit
        y: boxY * unit
        width: 6 * unit
        height: 17 * unit
        radius: width / 2
        rotation: 18
        antialiasing: true
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "#7cb2ff"
            }
            GradientStop {
                position: 1
                color: "#3a76e6"
            }
        }
    }

    component Flake: Rectangle {
        property real unit: 1
        property real boxX
        property real boxY

        x: boxX * unit
        y: boxY * unit
        width: 9 * unit
        height: width
        radius: width / 2
        antialiasing: true
        color: "#ffffff"
        border.width: Math.max(1, unit * 0.8)
        border.color: "#c9daf5"
    }

    component Bar: Rectangle {
        property real unit: 1
        property real boxX
        property real boxY
        property real boxWidth

        x: boxX * unit
        y: boxY * unit
        width: boxWidth * unit
        height: 9 * unit
        radius: height / 2
        antialiasing: true
        color: "#cfd2d8"
    }

    Sun {
        unit: glyph.unit
        visible: glyph.hasSun && glyph.day
        boxX: glyph.kind === "clear" ? 6 : glyph.kind === "mostly" ? 0 : 30
        boxY: glyph.kind === "clear" ? 6 : 0
        boxSize: glyph.kind === "clear" ? 88 : glyph.kind === "mostly" ? 86 : 70
    }

    Moon {
        unit: glyph.unit
        visible: glyph.hasSun && !glyph.day
        boxX: glyph.kind === "clear" ? 8 : glyph.kind === "mostly" ? 2 : 32
        boxY: glyph.kind === "clear" ? 8 : 0
        boxSize: glyph.kind === "clear" ? 84 : glyph.kind === "mostly" ? 80 : 64
    }

    Cloud {
        unit: glyph.unit
        visible: glyph.kind === "cloudy"
        boxX: 24
        boxY: 12
        boxWidth: 76
        light: "#d4d7dd"
        shade: "#a3a8b1"
    }

    Cloud {
        unit: glyph.unit
        visible: glyph.hasCloud
        boxX: glyph.kind === "mostly" ? 46 : glyph.kind === "partly" ? 0 : glyph.kind === "cloudy" ? 0 : 4
        boxY: glyph.kind === "mostly" ? 60 : glyph.kind === "partly" ? 42 : glyph.kind === "cloudy" ? 40 : 10
        boxWidth: glyph.kind === "mostly" ? 54 : glyph.kind === "partly" ? 86 : glyph.kind === "cloudy" ? 82 : 92
        light: glyph.kind === "storm" ? "#a7acb4" : glyph.kind === "rain" ? "#eeeff2" : "#faf7ef"
        shade: glyph.kind === "storm" ? "#6c717a" : glyph.kind === "rain" ? "#b6bac3" : "#d3d0c6"
    }

    Repeater {
        model: glyph.kind === "rain" ? [[30, 72], [50, 72], [70, 72]] : []
        delegate: Drop {
            required property var modelData
            unit: glyph.unit
            boxX: modelData[0]
            boxY: modelData[1]
        }
    }

    Repeater {
        model: glyph.kind === "snow" ? [[26, 74], [46, 82], [66, 74], [36, 90], [58, 92]] : []
        delegate: Flake {
            required property var modelData
            unit: glyph.unit
            boxX: modelData[0]
            boxY: modelData[1]
        }
    }

    Shape {
        visible: glyph.kind === "storm"
        width: 100
        height: 100
        scale: glyph.unit
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            strokeColor: "transparent"
            fillColor: "#ffd22e"
            PathSvg {
                path: "M 52 60 L 39 82 L 50 82 L 44 99 L 65 73 L 54 73 L 61 60 Z"
            }
        }
    }

    Repeater {
        model: glyph.kind === "fog" ? [[12, 30, 76], [18, 46, 64], [10, 62, 72]] : []
        delegate: Bar {
            required property var modelData
            unit: glyph.unit
            boxX: modelData[0]
            boxY: modelData[1]
            boxWidth: modelData[2]
        }
    }
}
