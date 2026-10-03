/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

Item {
    id: spring

    visible: false

    property real value: 0
    property real target: 0
    property real velocity: 0
    property real dampingRatio: M3.springSpatialDefaultDamping
    property real response: M3.springSpatialDefaultResponse

    readonly property bool running: frames.running

    signal settled()

    function animateTo(to: real, initialVelocity: var): void {
        target = to;
        if (initialVelocity !== undefined) {
            velocity = initialVelocity;
        }
        if (M3.motionScale <= 0) {
            jumpTo(to);
            settled();
            return;
        }
        frames.start();
    }

    function jumpTo(to: real): void {
        frames.stop();
        value = to;
        target = to;
        velocity = 0;
    }

    function stop(): void {
        frames.stop();
        velocity = 0;
    }

    FrameAnimation {
        id: frames

        onTriggered: {
            const dt = Math.min(frameTime, 1 / 30);
            const response = spring.response * Math.max(M3.motionScale, 0.05);
            const stiffness = Math.pow(2 * Math.PI / response, 2);
            const damping = 4 * Math.PI * spring.dampingRatio / response;
            const steps = Math.max(1, Math.ceil(dt / 0.004));
            const h = dt / steps;

            let x = spring.value;
            let v = spring.velocity;
            for (let i = 0; i < steps; ++i) {
                const acceleration = -stiffness * (x - spring.target) - damping * v;
                v += acceleration * h;
                x += v * h;
            }

            if (Math.abs(x - spring.target) < 0.0005 && Math.abs(v) < 0.005) {
                frames.stop();
                spring.velocity = 0;
                spring.value = spring.target;
                spring.settled();
                return;
            }
            spring.velocity = v;
            spring.value = x;
        }
    }
}
