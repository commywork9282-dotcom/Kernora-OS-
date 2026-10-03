/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.networkmanagement as PlasmaNM
import org.kernora.m3
import org.kernora.ui
import org.kernora.system
import "../components"

SettingsPage {
    id: page

    title: i18n("Network & internet")

    PlasmaNM.EnabledConnections { id: enabled }
    PlasmaNM.AvailableDevices { id: devices }
    PlasmaNM.NetworkStatus { id: status }
    PlasmaNM.Handler {
        id: handler
    }
    PlasmaNM.NetworkModel { id: networkModel }
    PlasmaNM.AppletProxyModel {
        id: connections
        sourceModel: networkModel
    }

    Timer {
        id: scanTimer
        interval: 10000
        repeat: true
        running: page.visible && enabled.wirelessEnabled
        triggeredOnStart: true
        onTriggered: handler.requestScan("")
    }

    readonly property bool wifiAvailable: devices.wirelessDeviceAvailable && enabled.wirelessHwEnabled
    readonly property bool airplane: PlasmaNM.Configuration.airplaneModeEnabled

    Instantiator {
        id: rows
        model: connections
        delegate: QtObject {
            required property int index
            required property var model
            readonly property int type: model.Type
            readonly property string name: model.ItemUniqueName
            readonly property int state: model.ConnectionState
            readonly property string uuid: model.Uuid
            readonly property string connectionPath: model.ConnectionPath
            readonly property string devicePath: model.DevicePath
            readonly property string specificPath: model.SpecificPath
            readonly property string ssid: model.Ssid
            readonly property int signal: model.Signal
            readonly property int securityType: model.SecurityType
            readonly property string securityString: model.SecurityTypeString
            readonly property string icon: model.ConnectionIcon
            readonly property string lastUsed: model.LastUsed
            readonly property var details: model.ConnectionDetails
            readonly property string section: model.Section
        }
        onObjectAdded: page.rebuild()
        onObjectRemoved: page.rebuild()
    }
    Connections {
        target: connections
        function onDataChanged() { rebuildTimer.restart(); }
        function onLayoutChanged() { rebuildTimer.restart(); }
    }
    Timer {
        id: rebuildTimer
        interval: 150
        onTriggered: page.rebuild()
    }

    property var wireless: []
    property var wired: []
    property var vpn: []

    function rebuild(): void {
        const w = [], e = [], v = [];
        for (let i = 0; i < rows.count; ++i) {
            const row = rows.objectAt(i);
            if (!row) {
                continue;
            }
            if (row.type === PlasmaNM.Enums.Wireless) {
                w.push(row);
            } else if (row.type === PlasmaNM.Enums.Wired) {
                e.push(row);
            } else if (row.type === PlasmaNM.Enums.Vpn || row.type === PlasmaNM.Enums.WireGuard) {
                v.push(row);
            }
        }
        const rank = row => row.state === PlasmaNM.Enums.Activated ? 0 : row.state === PlasmaNM.Enums.Activating ? 1 : row.uuid.length > 0 ? 2 : 3;
        w.sort((a, b) => rank(a) - rank(b) || b.signal - a.signal);
        wireless = w;
        wired = e;
        vpn = v;
    }

    function stateText(row: var): string {
        switch (row.state) {
        case PlasmaNM.Enums.Activated:
            return i18n("Connected");
        case PlasmaNM.Enums.Activating:
            return i18n("Connecting…");
        case PlasmaNM.Enums.Deactivating:
            return i18n("Disconnecting…");
        }
        if (row.type === PlasmaNM.Enums.Wireless) {
            if (row.uuid.length > 0) {
                return i18n("Saved");
            }
            return row.securityType === PlasmaNM.Enums.NoneSecurity ? i18n("Open network") : row.securityString;
        }
        return row.uuid.length > 0 ? i18n("Not connected") : i18n("Available");
    }

    function showDetails(row: var): void {
        page.open("NetworkDetailsPage.qml", {
            name: row.name,
            uuid: row.uuid,
            connectionPath: row.connectionPath,
            devicePath: row.devicePath,
            connected: row.state === PlasmaNM.Enums.Activated,
            wireless: row.type === PlasmaNM.Enums.Wireless,
            details: Array.from(row.details || []),
            handler: handler
        });
    }

    function isStaticPassword(row: var): bool {
        return [PlasmaNM.Enums.StaticWep, PlasmaNM.Enums.WpaPsk, PlasmaNM.Enums.Wpa2Psk, PlasmaNM.Enums.SAE].includes(row.securityType);
    }

    function activate(row: var): void {
        if (row.state === PlasmaNM.Enums.Activated || row.state === PlasmaNM.Enums.Activating) {
            page.showDetails(row);
            return;
        }
        if (row.uuid.length > 0) {
            handler.activateConnection(row.connectionPath, row.devicePath, row.specificPath);
        } else if (row.type === PlasmaNM.Enums.Wireless && isStaticPassword(row)) {
            passwordDialog.row = row;
            passwordDialog.open();
        } else {
            handler.addAndActivateConnection(row.devicePath, row.specificPath);
        }
    }

    HeroSwitch {
        width: parent.width
        visible: page.wifiAvailable || page.airplane
        title: i18n("Use Wi-Fi")
        checked: enabled.wirelessEnabled
        enabled: !page.airplane
        onToggled: checked => handler.enableWireless(checked)
    }

    Banner {
        width: parent.width
        visible: page.airplane
        tone: "neutral"
        icon: "airplane-mode"
        title: i18n("Airplane mode is on")
        text: i18n("Wi-Fi and Bluetooth are off until you turn airplane mode off.")
        actionText: i18n("Turn off")
        onActionTriggered: {
            handler.enableAirplaneMode(false);
            PlasmaNM.Configuration.airplaneModeEnabled = false;
        }
    }

    Group {
        title: i18n("Wi-Fi networks")
        visible: page.wifiAvailable && enabled.wirelessEnabled
        note: page.wireless.length === 0 ? i18n("Looking for networks…") : ""

        Repeater {
            model: page.wireless
            delegate: ListItem {
                id: wifiRow
                required property var modelData
                title: modelData.name
                subtitle: page.stateText(modelData)
                icon: modelData.icon
                accent: modelData.state === PlasmaNM.Enums.Activated ? 0 : -1
                iconStyle: modelData.state === PlasmaNM.Enums.Activated ? "circle" : "plain"
                trailing: Component {
                    RowLayout {
                        spacing: 4
                        MIcon {
                            size: 18
                            visible: wifiRow.modelData.securityType !== PlasmaNM.Enums.NoneSecurity
                            source: "object-locked"
                            color: M3.surfaceVariantContent
                        }
                        QQC2.BusyIndicator {
                            visible: wifiRow.modelData.state === PlasmaNM.Enums.Activating
                            running: visible
                            implicitWidth: 24
                            implicitHeight: 24
                        }
                        IconButton {
                            visible: wifiRow.modelData.uuid.length > 0
                            iconName: "configure"
                            text: i18n("Network details")
                            onClicked: page.showDetails(wifiRow.modelData)
                        }
                    }
                }
                onClicked: page.activate(modelData)
            }
        }
    }

    Group {
        title: i18n("Wired")
        visible: page.wired.length > 0

        Repeater {
            model: page.wired
            delegate: ListItem {
                required property var modelData
                title: modelData.name
                subtitle: page.stateText(modelData)
                icon: "network-wired"
                accent: modelData.state === PlasmaNM.Enums.Activated ? 1 : -1
                iconStyle: modelData.state === PlasmaNM.Enums.Activated ? "circle" : "plain"
                chevron: modelData.uuid.length > 0
                onClicked: {
                    if (modelData.state === PlasmaNM.Enums.Activated) {
                        page.showDetails(modelData);
                    } else {
                        page.activate(modelData);
                    }
                }
            }
        }
    }

    Group {
        title: i18n("VPN")
        visible: page.vpn.length > 0

        Repeater {
            model: page.vpn
            delegate: ListItem {
                required property var modelData
                title: modelData.name
                subtitle: page.stateText(modelData)
                icon: "network-vpn"
                accent: modelData.state === PlasmaNM.Enums.Activated ? 2 : -1
                iconStyle: modelData.state === PlasmaNM.Enums.Activated ? "circle" : "plain"
                checkable: true
                checked: modelData.state === PlasmaNM.Enums.Activated || modelData.state === PlasmaNM.Enums.Activating
                onToggled: on => on
                    ? handler.activateConnection(modelData.connectionPath, modelData.devicePath, modelData.specificPath)
                    : handler.deactivateConnection(modelData.connectionPath, modelData.devicePath)
            }
        }
    }

    Group {
        title: i18n("More")

        ListItem {
            title: i18n("Airplane mode")
            subtitle: i18n("Turns off Wi-Fi, Bluetooth and mobile data")
            icon: "airplane-mode"
            iconStyle: "plain"
            visible: devices.wirelessDeviceAvailable || devices.modemDeviceAvailable
            checkable: true
            checked: page.airplane
            onToggled: on => {
                handler.enableAirplaneMode(on);
                PlasmaNM.Configuration.airplaneModeEnabled = on;
            }
        }
        ListItem {
            title: i18n("Add a VPN or connection")
            subtitle: i18n("WireGuard, OpenVPN, hidden Wi-Fi, static addresses")
            icon: "list-add"
            iconStyle: "plain"
            chevron: true
            onClicked: Process.openModule("kcm_networkmanagement")
        }
        ListItem {
            title: i18n("Advanced network settings")
            subtitle: i18n("Addresses, DNS, proxy and every saved connection")
            icon: "preferences-system-network-proxy"
            iconStyle: "plain"
            chevron: true
            onClicked: Process.openModule("kcm_networkmanagement")
        }
    }

    Dialog {
        id: passwordDialog

        property var row: null

        icon: "network-wireless"
        title: row ? i18n("Connect to “%1”", row.name) : ""
        text: i18n("Enter the network password.")
        acceptText: i18n("Connect")
        acceptEnabled: password.text.length >= 8 || (row && row.securityType === PlasmaNM.Enums.StaticWep && password.text.length >= 5)
        onOpened: {
            password.text = "";
            password.forceActiveFocus();
        }
        onAccepted: {
            handler.addAndActivateConnection(row.devicePath, row.specificPath, password.text);
            password.text = "";
        }

        InputField {
            id: password
            Layout.fillWidth: true
            label: i18n("Password")
            password: true
            onAccepted: {
                if (passwordDialog.acceptEnabled) {
                    passwordDialog.accept();
                }
            }
        }
    }
}
