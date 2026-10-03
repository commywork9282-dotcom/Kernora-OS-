/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.bluezqt as BluezQt

QtObject {
    id: root

    readonly property bool available: BluezQt.Manager.bluetoothBlocked || BluezQt.Manager.adapters.length > 0
    readonly property bool on: BluezQt.Manager.bluetoothOperational

    readonly property string subtitle: {
        if (!available) {
            return i18n("Unavailable");
        }
        if (!on) {
            return i18n("Off");
        }
        const devices = BluezQt.Manager.connectedDevices;
        if (devices.length === 1) {
            return devices[0].name;
        }
        if (devices.length > 1) {
            return i18np("%1 device", "%1 devices", devices.length);
        }
        return i18n("On");
    }

    function toggle(): void {
        const enable = !on;
        BluezQt.Manager.bluetoothBlocked = !enable;
        BluezQt.Manager.adapters.forEach(adapter => {
            adapter.powered = enable;
        });
    }
}
