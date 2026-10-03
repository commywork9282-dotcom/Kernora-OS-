/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kernora.system

QtObject {
    readonly property bool dark: Appearance.dark
    readonly property bool busy: Appearance.busy

    function toggle(): void {
        if (!Appearance.busy) {
            Appearance.setDark(!Appearance.dark);
        }
    }
}
