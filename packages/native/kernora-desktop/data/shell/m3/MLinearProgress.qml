/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

Item {
    id: root

    property real value: 0
    property bool indeterminate: false
    property bool wavy: true
    property real thickness: 4
    property color color: M3.primary
    property color trackColor: M3.secondaryContainer

    readonly property bool waving: wavy && !M3.classic
    readonly property real gap: 4
    readonly property real fullAmplitude: 3
    readonly property real wavelength: indeterminate ? 24 : 32

    implicitWidth: 240
    implicitHeight: waving ? thickness + 2 * fullAmplitude + 2 : thickness

    property real shown: Math.max(0, Math.min(1, value))
    Behavior on shown {
        enabled: !root.indeterminate
        NumberAnimation {
            duration: M3.durationMedium2
            easing.type: Easing.Bezier
            easing.bezierCurve: M3.easingStandard
        }
    }

    property real amplitude: waving && (indeterminate || (shown > 0.1 && shown < 0.95)) ? fullAmplitude : 0
    Behavior on amplitude {
        NumberAnimation {
            duration: M3.durationLong2
            easing.type: Easing.Bezier
            easing.bezierCurve: M3.easingEmphasized
        }
    }

    property real phase: 0
    NumberAnimation on phase {
        running: root.visible && root.amplitude > 0 && M3.motionScale > 0
        from: 0
        to: 2 * Math.PI
        duration: 1000
        loops: Animation.Infinite
    }

    property real head1: 0
    property real tail1: 0
    property real head2: 0
    property real tail2: 0

    ParallelAnimation {
        running: root.indeterminate && root.visible
        loops: Animation.Infinite
        SequentialAnimation {
            PropertyAction { target: root; property: "tail1"; value: 0 }
            PropertyAction { target: root; property: "head2"; value: 0 }
            PropertyAction { target: root; property: "tail2"; value: 0 }
            NumberAnimation { target: root; property: "head1"; from: 0; to: 1; duration: 750; easing.type: Easing.Bezier; easing.bezierCurve: [0.2, 0, 0.8, 1, 1, 1] }
            PauseAnimation { duration: 1050 }
        }
        SequentialAnimation {
            PauseAnimation { duration: 333 }
            NumberAnimation { target: root; property: "tail1"; from: 0; to: 1; duration: 850; easing.type: Easing.Bezier; easing.bezierCurve: [0.4, 0, 1, 1, 1, 1] }
            PauseAnimation { duration: 617 }
        }
        SequentialAnimation {
            PauseAnimation { duration: 1000 }
            NumberAnimation { target: root; property: "head2"; from: 0; to: 1; duration: 567; easing.type: Easing.Bezier; easing.bezierCurve: [0, 0, 0.65, 1, 1, 1] }
            PauseAnimation { duration: 233 }
        }
        SequentialAnimation {
            PauseAnimation { duration: 1267 }
            NumberAnimation { target: root; property: "tail2"; from: 0; to: 1; duration: 533; easing.type: Easing.Bezier; easing.bezierCurve: [0.1, 0, 0.45, 1, 1, 1] }
        }
    }

    onShownChanged: canvas.requestPaint()
    onAmplitudeChanged: canvas.requestPaint()
    onPhaseChanged: canvas.requestPaint()
    onHead1Changed: canvas.requestPaint()
    onTail1Changed: canvas.requestPaint()
    onHead2Changed: canvas.requestPaint()
    onTail2Changed: canvas.requestPaint()
    onIndeterminateChanged: canvas.requestPaint()
    onWavingChanged: canvas.requestPaint()
    onColorChanged: canvas.requestPaint()
    onTrackColorChanged: canvas.requestPaint()
    onThicknessChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        transform: Scale {
            origin.x: canvas.width / 2
            xScale: root.LayoutMirroring.enabled ? -1 : 1
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width;
            const mid = height / 2;
            const s = root.thickness;
            const round = !M3.classic;
            const inset = round ? s / 2 : 0;
            ctx.lineWidth = s;
            ctx.lineCap = round ? "round" : "butt";

            function segment(x0, x1, colour, amp) {
                if (x1 - x0 < 0.5) {
                    return;
                }
                const a = x0 + inset;
                const b = x1 - inset;
                if (b <= a) {
                    ctx.fillStyle = colour;
                    ctx.beginPath();
                    ctx.arc((x0 + x1) / 2, mid, Math.min(s, x1 - x0) / 2, 0, 2 * Math.PI);
                    ctx.fill();
                    return;
                }
                ctx.strokeStyle = colour;
                ctx.beginPath();
                if (amp < 0.05) {
                    ctx.moveTo(a, mid);
                    ctx.lineTo(b, mid);
                } else {
                    const k = 2 * Math.PI / root.wavelength;
                    ctx.moveTo(a, mid + amp * Math.sin(a * k - root.phase));
                    for (let x = a + 1.5; x < b; x += 1.5) {
                        ctx.lineTo(x, mid + amp * Math.sin(x * k - root.phase));
                    }
                    ctx.lineTo(b, mid + amp * Math.sin(b * k - root.phase));
                }
                ctx.stroke();
            }

            if (root.indeterminate) {
                const lines = [];
                for (const pair of [[root.tail1, root.head1], [root.tail2, root.head2]]) {
                    if (pair[1] - pair[0] > 0.0005) {
                        lines.push([pair[0] * w, pair[1] * w]);
                    }
                }
                lines.sort((p, q) => p[0] - q[0]);
                let cursor = 0;
                for (const line of lines) {
                    if (line[0] - root.gap > cursor) {
                        segment(cursor, line[0] - root.gap, root.trackColor, 0);
                    }
                    cursor = Math.max(cursor, line[1] + root.gap);
                }
                if (cursor < w) {
                    segment(cursor, w, root.trackColor, 0);
                }
                for (const line of lines) {
                    segment(line[0], line[1], root.color, root.amplitude);
                }
                return;
            }

            const head = root.shown * w;
            if (head > 0.5) {
                segment(0, head, root.color, root.amplitude);
            }
            const start = head > 0.5 ? head + root.gap : 0;
            if (start < w - s) {
                segment(start, w, root.trackColor, 0);
                ctx.fillStyle = root.color;
                ctx.beginPath();
                if (round) {
                    ctx.arc(w - s / 2, mid, s / 2, 0, 2 * Math.PI);
                } else {
                    ctx.rect(w - s, mid - s / 2, s, s);
                }
                ctx.fill();
            }
        }
    }
}
