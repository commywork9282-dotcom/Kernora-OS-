/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import "m3"

Item {
    id: root

    visible: false

    property real travel: 520

    readonly property real progress: spring.value
    readonly property bool dragging: dragActive
    readonly property bool shown: spring.value > 0.001 || dragActive || spring.running
    readonly property bool opening: spring.target > 0.5

    property bool dragActive: false
    property real dragOrigin: 0
    property var samples: []

    MSpring {
        id: spring
        dampingRatio: 0.82
        response: 0.42
    }

    function open(velocity: var): void {
        spring.animateTo(1, velocity === undefined ? spring.velocity : velocity);
    }

    function close(velocity: var): void {
        spring.animateTo(0, velocity === undefined ? spring.velocity : velocity);
    }

    function toggle(): void {
        if (opening) {
            close();
        } else {
            open();
        }
    }

    function beginDrag(): void {
        if (dragActive) {
            return;
        }
        spring.stop();
        dragOrigin = spring.value;
        samples = [];
        dragActive = true;
    }

    function dragTo(upwards: real): void {
        if (!dragActive) {
            beginDrag();
        }
        const raw = dragOrigin + upwards / Math.max(1, travel);
        const now = Date.now();
        samples.push({ t: now, v: raw });
        while (samples.length > 2 && now - samples[0].t > 100) {
            samples.shift();
        }
        spring.jumpTo(resist(raw));
    }

    function endDrag(): void {
        if (!dragActive) {
            return;
        }
        dragActive = false;
        const velocity = measuredVelocity();
        let target;
        if (velocity > 1.2) {
            target = 1;
        } else if (velocity < -1.2) {
            target = 0;
        } else {
            target = spring.value > 0.5 ? 1 : 0;
        }
        spring.animateTo(target, Math.max(-8, Math.min(8, velocity)));
    }

    function cancelDrag(): void {
        if (dragActive) {
            dragActive = false;
            spring.animateTo(spring.value > 0.5 ? 1 : 0, 0);
        }
    }

    function resist(raw: real): real {
        if (raw <= 0) {
            return 0;
        }
        if (raw <= 1) {
            return raw;
        }
        const over = raw - 1;
        return 1 + 0.08 * (1 - 1 / (over * 6 + 1));
    }

    function measuredVelocity(): real {
        if (samples.length < 2) {
            return 0;
        }
        const first = samples[0];
        const last = samples[samples.length - 1];
        const dt = (last.t - first.t) / 1000;
        if (dt <= 0) {
            return 0;
        }
        return (last.v - first.v) / dt;
    }

    property real scrollTravel: 0

    function scrollBy(upwards: real): void {
        if (!dragActive) {
            beginDrag();
            scrollTravel = 0;
        }
        scrollTravel += upwards;
        dragTo(scrollTravel);
        scrollEnd.restart();
    }

    Timer {
        id: scrollEnd
        interval: 120
        onTriggered: root.endDrag()
    }

    function wheelNotch(upwards: bool): void {
        if (upwards) {
            open();
        } else {
            close();
        }
    }
}
