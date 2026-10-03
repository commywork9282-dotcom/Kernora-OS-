/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import "m3"

Item {
    id: root

    property real value: 0
    property bool playing: false
    property bool interactive: true
    property color color: M3.primary
    property color trackColor: Qt.alpha(color, 0.3)

    readonly property bool dragging: drag.pressed
    readonly property real shownValue: dragging ? drag.dragValue : value

    signal seekRequested(real value)

    implicitWidth: 200
    implicitHeight: 24

    readonly property real wavelength: 24
    readonly property real stroke: 3
    property real amplitude: playing && !dragging ? 3 : 0
    Behavior on amplitude {
        NumberAnimation {
            duration: M3.durationLong2
            easing.type: Easing.Bezier
            easing.bezierCurve: M3.easingEmphasized
        }
    }

    property real phase: 0
    NumberAnimation on phase {
        running: root.visible && root.amplitude > 0
        from: 0
        to: 2 * Math.PI
        duration: 1200
        loops: Animation.Infinite
    }

    onShownValueChanged: canvas.requestPaint()
    onPhaseChanged: canvas.requestPaint()
    onAmplitudeChanged: canvas.requestPaint()
    onColorChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const mid = height / 2;
            const head = Math.max(0, Math.min(1, root.shownValue)) * width;
            const gap = 6;
            ctx.lineCap = "round";
            ctx.lineWidth = root.stroke;

            if (head > gap) {
                ctx.strokeStyle = root.color;
                ctx.beginPath();
                const end = head - gap;
                for (let x = root.stroke / 2; x <= end; x += 1) {
                    const y = mid + root.amplitude * Math.sin(x / root.wavelength * 2 * Math.PI - root.phase);
                    if (x === root.stroke / 2) {
                        ctx.moveTo(x, y);
                    } else {
                        ctx.lineTo(x, y);
                    }
                }
                ctx.stroke();
            }

            if (head + gap < width - root.stroke / 2) {
                ctx.strokeStyle = root.trackColor;
                ctx.beginPath();
                ctx.moveTo(head + gap, mid);
                ctx.lineTo(width - root.stroke / 2, mid);
                ctx.stroke();
            }

            ctx.strokeStyle = root.color;
            ctx.lineWidth = 4;
            ctx.beginPath();
            ctx.moveTo(head, mid - 8);
            ctx.lineTo(head, mid + 8);
            ctx.stroke();
        }
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        anchors.topMargin: -8
        anchors.bottomMargin: -8
        enabled: root.interactive
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        property real dragValue: 0
        function valueAt(x: real): real {
            return Math.max(0, Math.min(1, x / root.width));
        }
        onPressed: mouse => dragValue = valueAt(mouse.x)
        onPositionChanged: mouse => dragValue = valueAt(mouse.x)
        onReleased: mouse => root.seekRequested(valueAt(mouse.x))
    }
}
