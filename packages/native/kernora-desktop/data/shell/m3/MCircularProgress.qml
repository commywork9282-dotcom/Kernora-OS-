/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

Item {
    id: root

    property bool running: true
    property bool wavy: true
    property color color: M3.primary
    property color trackColor: M3.secondaryContainer

    readonly property bool waving: wavy && !M3.classic
    readonly property real size: Math.min(width, height)
    readonly property real thickness: Math.max(2, Math.round(size / 10))
    readonly property real amplitude: waving ? Math.max(1, size * 0.035) : 0
    readonly property bool animating: running && visible && M3.motionScale > 0

    implicitWidth: 40
    implicitHeight: 40

    property real sweep: 90
    property real head: 0
    property real phase: 0

    SequentialAnimation on sweep {
        running: root.animating
        loops: Animation.Infinite
        NumberAnimation { from: 10; to: 270; duration: 667; easing.type: Easing.Bezier; easing.bezierCurve: [0.4, 0, 0.2, 1, 1, 1] }
        NumberAnimation { from: 270; to: 10; duration: 667; easing.type: Easing.Bezier; easing.bezierCurve: [0.4, 0, 0.2, 1, 1, 1] }
    }
    NumberAnimation on head {
        running: root.animating
        loops: Animation.Infinite
        from: 0
        to: 1080
        duration: 4000
    }
    NumberAnimation on phase {
        running: root.animating && root.waving
        loops: Animation.Infinite
        from: 0
        to: 2 * Math.PI
        duration: 1000
    }

    onSweepChanged: canvas.requestPaint()
    onHeadChanged: canvas.requestPaint()
    onPhaseChanged: canvas.requestPaint()
    onWavingChanged: canvas.requestPaint()
    onColorChanged: canvas.requestPaint()
    onTrackColorChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const s = root.thickness;
            const amp = root.amplitude;
            const radius = (root.size - s) / 2 - amp;
            if (radius <= 1) {
                return;
            }
            const cx = width / 2;
            const cy = height / 2;
            const start = (root.head - 90 - root.sweep / 2) * Math.PI / 180;
            const span = root.sweep * Math.PI / 180;
            const waves = Math.max(5, Math.round(2 * Math.PI * radius / 14));
            ctx.lineWidth = s;
            ctx.lineCap = "round";

            if (root.waving) {
                const gap = (4 + s) / radius;
                const rest = 2 * Math.PI - span - 2 * gap;
                if (rest > 0) {
                    ctx.strokeStyle = root.trackColor;
                    ctx.beginPath();
                    ctx.arc(cx, cy, radius, start + span + gap, start + span + gap + rest, false);
                    ctx.stroke();
                }
            }

            ctx.strokeStyle = root.color;
            ctx.beginPath();
            const step = 1.5 / radius;
            for (let t = 0; ; t += step) {
                const u = Math.min(t, span);
                const angle = start + u;
                const r = radius + amp * Math.sin(waves * u - root.phase);
                const x = cx + r * Math.cos(angle);
                const y = cy + r * Math.sin(angle);
                if (t === 0) {
                    ctx.moveTo(x, y);
                } else {
                    ctx.lineTo(x, y);
                }
                if (u >= span) {
                    break;
                }
            }
            ctx.stroke();
        }
    }
}
