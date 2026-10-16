/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Shapes
import "materialshapes.js" as MaterialShapes

Item {
    id: root

    property int count: 0
    property color color: M3.surfaceContent
    property int size: 22
    property int spacing: 8

    readonly property var sequence: ["cookie9", "sunny", "clover4", "pill", "flower", "gem", "cookie4", "softBurst", "puffy", "cookie6", "heart", "verySunny"]

    implicitWidth: Math.max(0, count * (size + spacing) - spacing)
    implicitHeight: size

    function shake(): void {
        jolt.restart();
    }

    onCountChanged: {
        while (shapes.count < root.count) {
            shapes.append({ shape: root.sequence[shapes.count % root.sequence.length] });
        }
        while (shapes.count > root.count) {
            shapes.remove(shapes.count - 1);
        }
        list.positionViewAtEnd();
    }

    ListModel {
        id: shapes
    }

    component Glyph: Shape {
        id: glyph
        property string name: "circle"
        property color tint: root.color
        width: MaterialShapes.units
        height: MaterialShapes.units
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            strokeColor: "transparent"
            fillColor: glyph.tint
            PathSvg {
                path: (MaterialShapes.shapes[glyph.name] || MaterialShapes.shapes.circle).path
            }
        }
    }

    ListView {
        id: list
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(root.width, Math.max(1, Math.floor((root.width + root.spacing) / (root.size + root.spacing))) * (root.size + root.spacing) - root.spacing)
        height: root.size * 1.6
        orientation: ListView.Horizontal
        interactive: false
        spacing: root.spacing
        clip: true
        model: shapes
        transform: Translate { id: nudge }

        delegate: Item {
            id: cell

            required property string shape

            width: root.size
            height: list.height

            property real grow: 0
            property real form: 0

            ParallelAnimation {
                id: appear
                running: true
                NumberAnimation {
                    target: cell
                    property: "grow"
                    from: 0
                    to: 1
                    duration: M3.durationMedium4
                    easing.type: Easing.OutBack
                    easing.overshoot: 2.2
                }
                NumberAnimation {
                    target: cell
                    property: "form"
                    from: 0
                    to: 1
                    duration: M3.durationLong2
                    easing.type: Easing.Bezier
                    easing.bezierCurve: M3.easingEmphasizedDecelerate
                }
            }

            Item {
                anchors.centerIn: parent
                width: root.size
                height: root.size
                scale: cell.grow
                rotation: (1 - cell.form) * -150

                Glyph {
                    name: "circle"
                    scale: root.size * 0.62 / MaterialShapes.units
                    transformOrigin: Item.Center
                    anchors.centerIn: parent
                    opacity: 1 - cell.form
                }
                Glyph {
                    name: cell.shape
                    scale: root.size / MaterialShapes.units * (0.7 + 0.3 * cell.form)
                    transformOrigin: Item.Center
                    anchors.centerIn: parent
                    opacity: cell.form
                }
            }
        }

        remove: Transition {
            NumberAnimation { property: "scale"; to: 0; duration: M3.durationShort4; easing.type: Easing.InBack }
            NumberAnimation { property: "opacity"; to: 0; duration: M3.durationShort4 }
        }
        displaced: Transition {
            NumberAnimation { property: "x"; duration: M3.durationMedium2; easing.type: Easing.Bezier; easing.bezierCurve: M3.easingEmphasizedDecelerate }
        }
    }

    SequentialAnimation {
        id: jolt
        NumberAnimation { target: nudge; property: "x"; to: -10; duration: 50 }
        NumberAnimation { target: nudge; property: "x"; to: 10; duration: 80 }
        NumberAnimation { target: nudge; property: "x"; to: -6; duration: 70 }
        NumberAnimation { target: nudge; property: "x"; to: 0; duration: 60 }
    }
}
