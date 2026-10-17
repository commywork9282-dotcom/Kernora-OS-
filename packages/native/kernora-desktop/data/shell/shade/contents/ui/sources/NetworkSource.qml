/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.plasma.networkmanagement as PlasmaNM

Item {
    id: root

    PlasmaNM.EnabledConnections {
        id: enabled
    }
    PlasmaNM.AvailableDevices {
        id: devices
    }
    PlasmaNM.NetworkStatus {
        id: status
    }
    PlasmaNM.ConnectionIcon {
        id: connection
    }
    PlasmaNM.Handler {
        id: handler
    }

    readonly property string statusIcon: connection.connectionIcon
    readonly property bool connecting: connection.connecting

    readonly property bool wifiAvailable: devices.wirelessDeviceAvailable && enabled.wirelessHwEnabled
    readonly property bool wifiOn: enabled.wirelessEnabled
    readonly property bool wifiConnected: statusIcon.startsWith("network-wireless")
        && !statusIcon.includes("disconnected") && !statusIcon.includes("offline")
        && !statusIcon.includes("acquiring")

    readonly property string connectionName: {
        const first = (status.activeConnections || "").split("\n")[0] || "";
        const colon = first.lastIndexOf(":");
        return colon > 0 ? first.slice(0, colon).trim() : first.trim();
    }

    readonly property string wifiSubtitle: {
        if (!wifiAvailable) {
            return i18n("Unavailable");
        }
        if (!wifiOn) {
            return i18n("Off");
        }
        if (connecting) {
            return i18n("Connecting…");
        }
        if (wifiConnected && connectionName.length > 0) {
            return connectionName;
        }
        return i18n("Not connected");
    }

    function toggleWifi(): void {
        handler.enableWireless(!wifiOn);
    }

    readonly property bool wiredConnected: statusIcon.startsWith("network-wired")
        && !statusIcon.includes("disconnected") && !statusIcon.includes("offline")
        && !statusIcon.includes("acquiring")

    readonly property bool internetAvailable: wifiAvailable || devices.wiredDeviceAvailable || wiredConnected
    readonly property bool internetOn: wiredConnected || (wifiAvailable && wifiOn && !airplaneOn)

    readonly property string internetIcon: {
        if (wiredConnected) {
            return "network-wired-activated";
        }
        if (!wifiAvailable || !wifiOn || airplaneOn) {
            return airplaneOn ? "airplane-mode" : "network-wireless-offline";
        }
        return statusIcon.startsWith("network-wireless") ? statusIcon : "network-wireless";
    }

    readonly property string internetSubtitle: {
        if (connecting) {
            return i18n("Connecting…");
        }
        if (wiredConnected) {
            return wifiConnected && connectionName.length > 0 ? connectionName : i18n("Ethernet");
        }
        if (airplaneOn) {
            return i18n("Airplane mode");
        }
        if (!wifiAvailable) {
            return devices.wiredDeviceAvailable ? i18n("Cable unplugged") : i18n("Unavailable");
        }
        if (!wifiOn) {
            return i18n("Wi-Fi off");
        }
        if (wifiConnected && connectionName.length > 0) {
            return connectionName;
        }
        return i18n("Not connected");
    }

    function toggleInternet(): void {
        if (wifiAvailable && !airplaneOn) {
            toggleWifi();
        }
    }

    readonly property bool airplaneAvailable: devices.wirelessDeviceAvailable || devices.modemDeviceAvailable
    readonly property bool airplaneOn: PlasmaNM.Configuration.airplaneModeEnabled

    function toggleAirplane(): void {
        const enable = !airplaneOn;
        handler.enableAirplaneMode(enable);
        PlasmaNM.Configuration.airplaneModeEnabled = enable;
    }
}
