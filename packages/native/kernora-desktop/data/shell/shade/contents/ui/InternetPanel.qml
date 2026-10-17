/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.networkmanagement as PlasmaNM
import "m3"

ColumnLayout {
    id: panel

    required property QtObject backend
    signal back()
    signal requestClose()

    spacing: 12

    PlasmaNM.EnabledConnections { id: enabled }
    PlasmaNM.AvailableDevices { id: devices }
    PlasmaNM.Handler { id: handler }
    PlasmaNM.NetworkModel { id: networkModel }
    PlasmaNM.AppletProxyModel {
        id: connections
        sourceModel: networkModel
    }

    readonly property bool wifiAvailable: devices.wirelessDeviceAvailable && enabled.wirelessHwEnabled
    readonly property bool airplane: PlasmaNM.Configuration.airplaneModeEnabled
    property string asking: ""

    Timer {
        interval: 10000
        repeat: true
        running: panel.visible && enabled.wirelessEnabled
        triggeredOnStart: true
        onTriggered: handler.requestScan("")
    }

    Instantiator {
        id: rows
        model: connections
        delegate: QtObject {
            required property var model
            readonly property int type: model.Type
            readonly property string name: model.ItemUniqueName
            readonly property int state: model.ConnectionState
            readonly property string uuid: model.Uuid
            readonly property string connectionPath: model.ConnectionPath
            readonly property string devicePath: model.DevicePath
            readonly property string specificPath: model.SpecificPath
            readonly property int signal: model.Signal
            readonly property int securityType: model.SecurityType
            readonly property string icon: model.ConnectionIcon
        }
        onObjectAdded: rebuild.restart()
        onObjectRemoved: rebuild.restart()
    }
    Connections {
        target: connections
        function onDataChanged() { rebuild.restart(); }
        function onLayoutChanged() { rebuild.restart(); }
    }
    Timer {
        id: rebuild
        interval: 150
        onTriggered: {
            const wireless = [], wired = [];
            for (let i = 0; i < rows.count; ++i) {
                const row = rows.objectAt(i);
                if (!row) {
                    continue;
                }
                if (row.type === PlasmaNM.Enums.Wireless) {
                    wireless.push(row);
                } else if (row.type === PlasmaNM.Enums.Wired && row.uuid.length > 0) {
                    wired.push(row);
                }
            }
            const rank = row => row.state === PlasmaNM.Enums.Activated ? 0 : row.state === PlasmaNM.Enums.Activating ? 1 : row.uuid.length > 0 ? 2 : 3;
            wireless.sort((a, b) => rank(a) - rank(b) || b.signal - a.signal);
            wired.sort((a, b) => rank(a) - rank(b));
            panel.wireless = wireless.slice(0, 12);
            panel.wired = wired.filter(row => row.state !== PlasmaNM.Enums.Deactivated || wired.length === 1);
        }
    }

    property var wireless: []
    property var wired: []

    function stateText(row: var): string {
        switch (row.state) {
        case PlasmaNM.Enums.Activated:
            return i18n("Connected");
        case PlasmaNM.Enums.Activating:
            return i18n("Connecting…");
        case PlasmaNM.Enums.Deactivating:
            return i18n("Disconnecting…");
        }
        if (row.type === PlasmaNM.Enums.Wired) {
            return i18n("Cable unplugged");
        }
        if (row.uuid.length > 0) {
            return i18n("Saved");
        }
        if (row.securityType === PlasmaNM.Enums.NoneSecurity) {
            return i18n("Open");
        }
        return secured(row) ? i18n("Secured") : i18n("Available");
    }

    function secured(row: var): bool {
        return row.securityType !== PlasmaNM.Enums.NoneSecurity && row.securityType !== PlasmaNM.Enums.UnknownSecurity;
    }

    function needsPassword(row: var): bool {
        return [PlasmaNM.Enums.StaticWep, PlasmaNM.Enums.WpaPsk, PlasmaNM.Enums.Wpa2Psk, PlasmaNM.Enums.SAE].includes(row.securityType);
    }

    function activate(row: var): void {
        if (row.state === PlasmaNM.Enums.Activated || row.state === PlasmaNM.Enums.Activating) {
            handler.deactivateConnection(row.connectionPath, row.devicePath);
        } else if (row.uuid.length > 0) {
            handler.activateConnection(row.connectionPath, row.devicePath, row.specificPath);
        } else if (needsPassword(row)) {
            panel.asking = row.name;
        } else {
            handler.addAndActivateConnection(row.devicePath, row.specificPath);
        }
    }

    PanelHeader {
        Layout.fillWidth: true
        title: i18n("Internet")
        switchVisible: panel.wifiAvailable && !panel.airplane
        switchChecked: enabled.wirelessEnabled
        onBack: panel.back()
        onSwitched: checked => handler.enableWireless(checked)
    }

    MText {
        Layout.fillWidth: true
        Layout.leftMargin: 8
        visible: panel.airplane
        role: "bodyMedium"
        color: M3.surfaceVariantContent
        wrapMode: Text.Wrap
        text: i18n("Airplane mode is on. Wi-Fi stays off until you turn it off.")
    }

    PanelGroup {
        Layout.fillWidth: true
        visible: panel.wired.length > 0

        Repeater {
            model: panel.wired
            delegate: PanelRow {
                required property var modelData
                width: parent.width
                icon: "network-wired"
                title: i18n("Ethernet")
                subtitle: panel.stateText(modelData)
                active: modelData.state === PlasmaNM.Enums.Activated
            }
        }
    }

    PanelGroup {
        Layout.fillWidth: true
        visible: panel.wifiAvailable && enabled.wirelessEnabled && !panel.airplane

        MText {
            visible: panel.wireless.length === 0
            width: parent.width
            topPadding: 12
            bottomPadding: 12
            horizontalAlignment: Text.AlignHCenter
            role: "bodyMedium"
            color: M3.surfaceVariantContent
            text: i18n("Looking for networks…")
        }

        Repeater {
            model: panel.wireless
            delegate: Column {
                id: entry
                required property var modelData
                width: parent.width

                PanelRow {
                    width: parent.width
                    icon: entry.modelData.icon
                    title: entry.modelData.name
                    subtitle: panel.stateText(entry.modelData)
                    active: entry.modelData.state === PlasmaNM.Enums.Activated
                    busy: entry.modelData.state === PlasmaNM.Enums.Activating
                    trailingIcon: panel.secured(entry.modelData) ? "object-locked" : ""
                    onClicked: panel.activate(entry.modelData)
                }

                RowLayout {
                    visible: panel.asking === entry.modelData.name
                    width: parent.width
                    spacing: 8

                    QQC2.TextField {
                        id: password
                        Layout.fillWidth: true
                        Layout.leftMargin: 12
                        echoMode: TextInput.Password
                        placeholderText: i18n("Password")
                        onVisibleChanged: if (visible) { text = ""; forceActiveFocus(); }
                        onAccepted: connectButton.clicked()
                    }
                    MButton {
                        id: connectButton
                        Layout.rightMargin: 4
                        variant: "filled"
                        text: i18n("Connect")
                        enabled: password.text.length >= 8 || (entry.modelData.securityType === PlasmaNM.Enums.StaticWep && password.text.length >= 5)
                        onClicked: {
                            handler.addAndActivateConnection(entry.modelData.devicePath, entry.modelData.specificPath, password.text);
                            panel.asking = "";
                        }
                    }
                }
            }
        }
    }

    MButton {
        Layout.alignment: Qt.AlignRight
        variant: "tonal"
        icon: "configure"
        text: i18n("Network settings")
        onClicked: {
            panel.backend.openSettings("network");
            panel.requestClose();
        }
    }
}
