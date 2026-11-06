/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.bluezqt as BluezQt
import org.kernora.m3
import org.kernora.ui
import org.kernora.system
import "../components"
import "../components/BluetoothNames.js" as BluetoothNames

SettingsPage {
    id: page

    title: i18n("Pair a new device")
    subtitle: i18n("Make sure the device is in pairing mode and close by.")

    readonly property var manager: BluezQt.Manager
    readonly property var adapter: manager.usableAdapter
    property string pairing: ""
    property string failed: ""

    property bool showUnnamed: false
    readonly property var found: Array.from(manager.devices)
        .filter(device => !device.paired)
        .sort(BluetoothNames.compareDevices)
    readonly property var named: found.filter(device => BluetoothNames.deviceName(device).length > 0)
    readonly property var unnamed: found.filter(device => BluetoothNames.deviceName(device).length === 0)

    BluetoothDiscovery {
        id: discovery
        adapterPath: page.adapter ? page.adapter.ubi : ""
        active: page.visible && page.manager.bluetoothOperational && !!page.adapter && page.adapter.powered
    }

    function pair(device: var): void {
        pairing = device.address;
        failed = "";
        const call = device.pair();
        call.finished.connect(() => {
            pairing = "";
            if (call.error) {
                failed = device.address;
                page.notify(i18n("Couldn't pair with %1", BluetoothNames.deviceName(device) || device.address));
                return;
            }
            device.trusted = true;
            device.connectToDevice();
            page.notify(i18n("Paired with %1", BluetoothNames.deviceName(device) || device.address));
            page.back();
        });
    }

    RowLayout {
        width: parent.width
        spacing: 16

        LinearProgress {
            Layout.fillWidth: true
            indeterminate: discovery.busy || discovery.scanning
            visible: indeterminate
        }
        MText {
            role: "labelLarge"
            color: M3.surfaceVariantContent
            text: discovery.errorString.length > 0 ? i18n("Couldn't search for devices.")
                : !page.adapter ? i18n("Waiting for a Bluetooth adapter…")
                : discovery.busy || discovery.scanning ? i18n("Searching…") : ""
        }
        QQC2.Button {
            text: i18n("Try again")
            visible: discovery.errorString.length > 0
            onClicked: discovery.retry()
        }
    }

    Group {
        title: i18n("Available devices")
        note: page.named.length === 0
            ? page.unnamed.length > 0 ? i18n("Some devices haven't provided a name yet.") : i18n("No devices found yet.")
            : ""

        Repeater {
            model: page.named
            delegate: BluetoothPairRow {
                required property var modelData
                device: modelData
                pairingAddress: page.pairing
                failedAddress: page.failed
                onPairRequested: device => page.pair(device)
            }
        }
    }

    Group {
        visible: page.unnamed.length > 0
        note: i18n("Some devices do not broadcast a name. You can identify them by their Bluetooth address.")

        ListItem {
            title: i18n("Show devices without names (%1)", page.unnamed.length)
            icon: "preferences-system-bluetooth"
            checkable: true
            checked: page.showUnnamed
            onToggled: checked => page.showUnnamed = checked
        }
        Repeater {
            model: page.showUnnamed ? page.unnamed : []
            delegate: BluetoothPairRow {
                required property var modelData
                device: modelData
                pairingAddress: page.pairing
                failedAddress: page.failed
                onPairRequested: device => page.pair(device)
            }
        }
    }
}
