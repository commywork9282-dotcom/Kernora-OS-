/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
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

    readonly property bool running: Plasmoid.configuration.running
    property real now: Date.now()
    readonly property real elapsed: Plasmoid.configuration.elapsed
        + (running ? Math.max(0, now - Plasmoid.configuration.startedAt) : 0)

    toolTipMainText: i18n("Stopwatch")
    toolTipSubText: ""

    function toggle() {
        const time = Date.now();
        if (running) {
            Plasmoid.configuration.elapsed = Plasmoid.configuration.elapsed + Math.max(0, time - Plasmoid.configuration.startedAt);
            Plasmoid.configuration.running = false;
        } else {
            Plasmoid.configuration.startedAt = time;
            Plasmoid.configuration.running = true;
        }
        now = time;
    }

    function lap() {
        if (running) {
            Plasmoid.configuration.laps = Plasmoid.configuration.laps + 1;
        }
    }

    function clear() {
        Plasmoid.configuration.running = false;
        Plasmoid.configuration.elapsed = 0;
        Plasmoid.configuration.startedAt = 0;
        Plasmoid.configuration.laps = 0;
        now = Date.now();
    }

    Timer {
        running: root.running
        repeat: true
        triggeredOnStart: true
        interval: Math.max(50, 1000 - Math.floor(root.elapsed) % 1000)
        onTriggered: root.now = Date.now()
    }

    fullRepresentation: Item {
        LiftHandler {}

        Layout.preferredWidth: root.inPanel ? 270 : -1
        Layout.preferredHeight: root.inPanel ? 270 : -1
        Layout.minimumWidth: 120
        Layout.minimumHeight: 120
        Layout.maximumWidth: root.inPanel ? Layout.preferredWidth : Infinity
        Layout.maximumHeight: root.inPanel ? Layout.preferredHeight : Infinity

        StopwatchFace {
            anchors.fill: parent
            elapsed: root.elapsed
            running: root.running
            laps: Plasmoid.configuration.laps
            lapText: i18n("Lap %1", Plasmoid.configuration.laps + 1)
            onToggled: root.toggle()
            onLapped: root.lap()
            onCleared: root.clear()
        }
    }
}
