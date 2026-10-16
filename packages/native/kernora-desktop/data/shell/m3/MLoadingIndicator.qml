/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import "loadingshapes.js" as LoadingShapes

Item {
    id: root

    property bool running: true
    property bool contained: false
    property color color: contained ? M3.primaryContainerContent : M3.primary
    property color containerColor: M3.primaryContainer

    readonly property bool animating: running && visible && !M3.classic && M3.motionScale > 0

    implicitWidth: 48
    implicitHeight: 48

    property int turns: 0
    property real morph: 1
    property real spin: 0

    SequentialAnimation {
        running: root.animating
        loops: Animation.Infinite
        ScriptAction {
            script: {
                root.turns += 1;
                root.morph = 0;
            }
        }
        NumberAnimation {
            target: root
            property: "morph"
            from: 0
            to: 1
            duration: 650
            easing.type: Easing.OutBack
            easing.overshoot: 1.4
        }
    }

    NumberAnimation on spin {
        running: root.animating
        from: 0
        to: 360
        duration: 4666
        loops: Animation.Infinite
    }

    onMorphChanged: canvas.requestPaint()
    onSpinChanged: canvas.requestPaint()
    onColorChanged: canvas.requestPaint()
    onContainerColorChanged: canvas.requestPaint()
    onContainedChanged: canvas.requestPaint()

    MCircularProgress {
        anchors.fill: parent
        visible: M3.classic
        running: root.running && M3.classic
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        visible: !M3.classic
        renderStrategy: Canvas.Cooperative

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const size = Math.min(width, height);
            const cx = width / 2;
            const cy = height / 2;
            if (root.contained) {
                ctx.fillStyle = root.containerColor;
                ctx.beginPath();
                ctx.arc(cx, cy, size / 2, 0, 2 * Math.PI);
                ctx.fill();
            }
            const count = LoadingShapes.shapes.length;
            const to = LoadingShapes.shapes[root.turns % count];
            const from = LoadingShapes.shapes[(root.turns + count - 1) % count];
            const n = LoadingShapes.samples;
            const scale = size * (root.contained ? 0.66 : 0.79);
            const t = root.morph;
            const turn = (root.spin + 90 * (root.turns - 1 + Math.min(1, t))) * Math.PI / 180;
            ctx.fillStyle = root.color;
            ctx.beginPath();
            for (let k = 0; k < n; ++k) {
                const r = Math.max(0, from[k] + (to[k] - from[k]) * t) * scale;
                const a = 2 * Math.PI * k / n + turn;
                const x = cx + r * Math.cos(a);
                const y = cy + r * Math.sin(a);
                if (k === 0) {
                    ctx.moveTo(x, y);
                } else {
                    ctx.lineTo(x, y);
                }
            }
            ctx.closePath();
            ctx.fill();
        }
    }
}
