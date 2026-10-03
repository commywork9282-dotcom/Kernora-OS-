/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.plasma.private.battery

BatteryControlModel {
    id: battery

    readonly property bool hasBattery: hasInternalBatteries
    readonly property int batteryPercent: percent
    readonly property bool charging: pluggedIn && state === BatteryControlModel.Charging

    readonly property string batteryIcon: {
        if (charging) {
            return "battery-charging";
        }
        const level = Math.max(0, Math.min(100, Math.round(percent / 10) * 10));
        return "battery-" + String(level).padStart(3, "0");
    }
}
