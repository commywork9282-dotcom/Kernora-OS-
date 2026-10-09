/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Shapes
import "materialshapes.js" as MaterialShapes

Item {
    id: root

    property string shape: "cookie9"
    property color color: "white"
    readonly property real side: Math.min(width, height)

    Shape {
        width: MaterialShapes.units
        height: MaterialShapes.units
        scale: root.side / MaterialShapes.units
        transformOrigin: Item.TopLeft
        x: (root.width - root.side) / 2
        y: (root.height - root.side) / 2
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            strokeColor: "transparent"
            fillColor: root.color
            PathSvg {
                path: (MaterialShapes.shapes[root.shape] || MaterialShapes.shapes.circle).path
            }
        }
    }
}
