/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma Singleton

import QtQuick

QtObject {
    readonly property color light: "#ffffff"
    readonly property color dark: "#1f1f1f"

    property var screens: ({})

    function report(screen: string, left: bool, right: bool): void {
        const old = screens[screen];
        if (old && old.left === left && old.right === right) {
            return;
        }
        const next = Object.assign({}, screens);
        next[screen] = { left: left, right: right };
        screens = next;
    }

    function darkInk(screen: string, side: string): bool {
        if (LauncherState.screen === screen && LauncherState.scrim > 0.25) {
            return false;
        }
        const entry = screens[screen];
        return !!entry && !!entry[side];
    }

    function ink(screen: string, side: string): color {
        return darkInk(screen, side) ? dark : light;
    }
}
