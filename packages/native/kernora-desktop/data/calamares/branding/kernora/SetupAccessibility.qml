/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import io.calamares.core 1.0

import QtQuick
import org.kernora.m3

QtObject {
    id: setup

    property real baseScale: 0
    property real points: 10.5
    property bool reduceMotion: false

    function read(): void {
        let chosen = {};
        try {
            chosen = JSON.parse(String(Global.value("kernoraAccessibility") || "{}"));
        } catch (error) {
            chosen = {};
        }
        const size = Number(chosen.fontSize);
        setup.points = size > 10.5 ? size : 10.5;
        setup.reduceMotion = chosen.reduceMotion === true;
        M3.scaleOverride = setup.points > 10.5 ? setup.baseScale * setup.points / 10.5 : 0;
        M3.motionOverride = setup.reduceMotion ? 0 : -1;
    }

    property Connections watcher: Connections {
        target: Global
        function onChanged() {
            Qt.callLater(setup.read);
        }
    }

    Component.onCompleted: {
        setup.baseScale = M3.scale;
        setup.read();
    }
}
