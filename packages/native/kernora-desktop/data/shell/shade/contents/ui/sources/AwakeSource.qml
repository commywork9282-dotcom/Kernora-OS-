/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.plasma.private.batterymonitor

InhibitionControl {
    id: inhibition

    isSilent: true

    readonly property bool on: isManuallyInhibited

    function toggle(): void {
        if (on) {
            uninhibit();
        } else {
            inhibit(i18n("Keep Awake is on in Quick Settings"));
        }
    }
}
