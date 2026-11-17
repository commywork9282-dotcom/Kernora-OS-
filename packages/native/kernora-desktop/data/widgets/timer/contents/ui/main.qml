/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.notification
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    readonly property bool inPanel: Plasmoid.formFactor !== PlasmaCore.Types.Planar
    preferredRepresentation: inPanel ? null : fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    switchWidth: Plasmoid.configuration.placed ? 0 : 120
    switchHeight: Plasmoid.configuration.placed ? 0 : 120

    Timer {
        running: !Plasmoid.configuration.placed
        interval: 2000
        onTriggered: Plasmoid.configuration.placed = true
    }

    property real now: Date.now()
    property var timers: ({})
    property var alerts: ({})

    readonly property var presets: {
        const list = [];
        const raw = String(Plasmoid.configuration.presets || "").split(",");
        for (let i = 0; i < raw.length && list.length < 3; ++i) {
            const value = Number(raw[i]);
            if (value > 0 && list.indexOf(value) < 0) {
                list.push(value);
            }
        }
        return list.length > 0 ? list : [600, 60, 300];
    }

    readonly property var items: presets.map(seconds => {
        const state = timers[String(seconds)];
        const total = seconds * 1000;
        if (!state) {
            return { label: presetLabel(seconds), state: "idle", remaining: total, total: total };
        }
        const remaining = state.state === "running" ? Math.max(0, state.endsAt - now)
            : state.state === "paused" ? state.left : 0;
        return { label: presetLabel(seconds), state: state.state, remaining: remaining, total: total };
    })

    readonly property bool ticking: {
        for (const key in timers) {
            if (timers[key].state === "running") {
                return true;
            }
        }
        return false;
    }

    toolTipMainText: i18n("Timers")
    toolTipSubText: ""

    function presetLabel(seconds: int): string {
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor(seconds % 3600 / 60);
        const rest = seconds % 60;
        if (hours > 0) {
            return minutes > 0 ? i18nc("@label timer length", "%1h %2m", hours, minutes) : i18nc("@label timer length", "%1h", hours);
        }
        if (minutes > 0) {
            return rest > 0 ? i18nc("@label timer length", "%1m %2s", minutes, rest) : i18nc("@label timer length", "%1m", minutes);
        }
        return i18nc("@label timer length", "%1s", rest);
    }

    function store(next: var) {
        timers = next;
        Plasmoid.configuration.timers = JSON.stringify(next);
    }

    function copy(): var {
        return JSON.parse(JSON.stringify(timers));
    }

    function start(seconds: int) {
        const next = copy();
        next[String(seconds)] = { state: "running", endsAt: Date.now() + seconds * 1000 };
        now = Date.now();
        store(next);
    }

    function clear(seconds: int) {
        const next = copy();
        delete next[String(seconds)];
        store(next);
        silence(seconds);
    }

    function activate(index: int) {
        const seconds = presets[index];
        if (seconds === undefined) {
            return;
        }
        const key = String(seconds);
        const state = timers[key];
        const time = Date.now();
        now = time;
        if (!state) {
            start(seconds);
        } else if (state.state === "running") {
            const next = copy();
            next[key] = { state: "paused", left: Math.max(0, state.endsAt - time) };
            store(next);
        } else if (state.state === "paused") {
            const next = copy();
            next[key] = { state: "running", endsAt: time + state.left };
            store(next);
        } else {
            clear(seconds);
        }
    }

    function cancel(index: int) {
        if (presets[index] !== undefined) {
            clear(presets[index]);
        }
    }

    function add(seconds: int) {
        if (seconds <= 0) {
            return;
        }
        const list = [seconds].concat(presets.filter(value => value !== seconds));
        while (list.length > 3) {
            let drop = list.length - 1;
            for (let i = list.length - 1; i > 0; --i) {
                if (!timers[String(list[i])]) {
                    drop = i;
                    break;
                }
            }
            list.splice(drop, 1);
        }
        Plasmoid.configuration.presets = list.join(",");
        start(seconds);
    }

    function check() {
        const time = Date.now();
        now = time;
        let changed = false;
        const next = copy();
        for (const key in next) {
            const state = next[key];
            if (state.state === "running" && state.endsAt <= time) {
                next[key] = { state: "done" };
                changed = true;
                ring(Number(key));
            }
        }
        if (changed) {
            store(next);
        }
    }

    function ring(seconds: int) {
        silence(seconds);
        const alert = alertComponent.createObject(root, {
            seconds: seconds,
            text: i18n("%1 timer", presetLabel(seconds))
        });
        const map = Object.assign({}, alerts);
        map[String(seconds)] = alert;
        alerts = map;
        alert.sendEvent();
    }

    function silence(seconds: int) {
        const key = String(seconds);
        const alert = alerts[key];
        if (!alert) {
            return;
        }
        const map = Object.assign({}, alerts);
        delete map[key];
        alerts = map;
        alert.close();
        alert.destroy();
    }

    Component {
        id: alertComponent

        Notification {
            id: alert

            property int seconds

            componentName: "kernora-clock"
            eventId: "timerFinished"
            title: i18n("Time's up")
            iconName: "org.kernora.clock"
            urgency: Notification.HighUrgency
            flags: Notification.Persistent | Notification.LoopSound
            autoDelete: false
            actions: [
                NotificationAction {
                    label: i18n("Stop")
                    onActivated: root.clear(alert.seconds)
                }
            ]
            onClosed: {
                if (root.alerts[String(alert.seconds)] === alert) {
                    root.clear(alert.seconds);
                }
            }
        }
    }

    Component.onCompleted: {
        let saved = {};
        try {
            saved = JSON.parse(Plasmoid.configuration.timers || "{}");
        } catch (error) {
            saved = {};
        }
        const time = Date.now();
        const next = {};
        for (const key in saved) {
            const state = saved[key];
            if (state.state === "running" && state.endsAt <= time - 60000) {
                continue;
            }
            if (state.state === "done") {
                continue;
            }
            next[key] = state;
        }
        timers = next;
        Plasmoid.configuration.timers = JSON.stringify(next);
        check();
    }

    Timer {
        running: root.ticking
        repeat: true
        triggeredOnStart: true
        interval: {
            let wait = 1000;
            for (const key in root.timers) {
                const state = root.timers[key];
                if (state.state === "running") {
                    const left = state.endsAt - root.now;
                    wait = Math.min(wait, left > 0 ? (left % 1000 || 1000) + 5 : 5);
                }
            }
            return Math.max(5, wait);
        }
        onTriggered: root.check()
    }

    fullRepresentation: Item {
        id: full

        LiftHandler {}

        Layout.preferredWidth: root.inPanel ? 272 : -1
        Layout.preferredHeight: root.inPanel ? 284 : -1
        Layout.minimumWidth: 80
        Layout.minimumHeight: 80
        Layout.maximumWidth: root.inPanel ? Layout.preferredWidth : Infinity
        Layout.maximumHeight: root.inPanel ? Layout.preferredHeight : Infinity

        TimerFace {
            anchors.fill: parent
            items: root.items
            title: i18n("Timers")
            onActivated: index => root.activate(index)
            onCancelled: index => root.cancel(index)
            onAdded: keypad.openFor(full)
        }

        TimerKeypad {
            id: keypad
            onStarted: seconds => root.add(seconds)
        }
    }
}
