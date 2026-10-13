/*
    SPDX-FileCopyrightText: 2026 Lumo contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.plasma.private.batterymonitor

PowerProfilesControl {
    id: control

    readonly property bool available: isPowerProfileDaemonInstalled && profiles.length > 0
    readonly property string profile: activeProfile
    readonly property var order: ["power-saver", "balanced", "performance"].filter(p => profiles.includes(p))
    property string profileBeforeGaming: ""
    readonly property bool gaming: profileBeforeGaming.length > 0

    function next(): void {
        if (order.length === 0) {
            return;
        }
        const index = order.indexOf(activeProfile);
        setProfile(order[(index + 1) % order.length]);
    }

    function startGaming(): void {
        if (gaming) {
            return;
        }
        profileBeforeGaming = activeProfile.length > 0 ? activeProfile : "balanced";
        if (profiles.includes("performance")) {
            setProfile("performance");
        }
    }

    function stopGaming(): void {
        if (!gaming) {
            return;
        }
        if (profiles.includes(profileBeforeGaming)) {
            setProfile(profileBeforeGaming);
        }
        profileBeforeGaming = "";
    }
}
