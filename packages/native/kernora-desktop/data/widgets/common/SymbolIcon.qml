/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Shapes

Item {
    id: icon

    property string path
    property color color: "black"
    property real size: 24

    width: size
    height: size

    Shape {
        y: icon.size
        width: 960
        height: 960
        scale: icon.size / 960
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            strokeColor: "transparent"
            fillColor: icon.color
            PathSvg {
                path: icon.path
            }
        }
    }
}
