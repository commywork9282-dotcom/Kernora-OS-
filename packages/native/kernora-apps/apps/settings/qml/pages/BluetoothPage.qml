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

SettingsPage {
    id: page

    title: i18n("Bluetooth")

    readonly property var manager: BluezQt.Manager
    readonly property bool available: manager.adapters.length > 0 || manager.bluetoothBlocked
    readonly property bool on: manager.bluetoothOperational
    readonly property var adapter: manager.usableAdapter || (manager.adapters.length > 0 ? manager.adapters[0] : null)

    function setPower(enable: bool): void {
        manager.bluetoothBlocked = !enable;
        for (const a of Array.from(manager.adapters)) {
            a.powered = enable;
        }
    }

    readonly property var paired: {
        const all = Array.from(manager.devices);
        return all.filter(d => d.paired).sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name));
    }

    function deviceIcon(device: var): string {
        switch (device.type) {
        case BluezQt.Device.Headset:
        case BluezQt.Device.Headphones:
            return "audio-headphones";
        case BluezQt.Device.AudioVideo:
        case BluezQt.Device.OtherAudio:
            return "audio-speakers";
        case BluezQt.Device.Keyboard:
            return "input-keyboard";
        case BluezQt.Device.Mouse:
            return "input-mouse";
        case BluezQt.Device.Phone:
            return "smartphone";
        case BluezQt.Device.Computer:
            return "computer";
        case BluezQt.Device.Joypad:
            return "preferences-desktop-gaming";
        case BluezQt.Device.Tablet:
            return "input-tablet";
        }
        return "preferences-system-bluetooth";
    }

    function deviceStatus(device: var): string {
        const parts = [];
        parts.push(device.connected ? i18n("Connected") : i18n("Not connected"));
        if (device.battery) {
            parts.push(i18n("%1% battery", device.battery.percentage));
        }
        return parts.join(" · ");
    }

    EmptyState {
        visible: !page.available
        icon: "bluetooth-disabled"
        title: i18n("No Bluetooth adapter")
        text: i18n("This computer has no Bluetooth, or its adapter is switched off in hardware.")
    }

    HeroSwitch {
        width: parent.width
        visible: page.available
        title: i18n("Use Bluetooth")
        checked: page.on
        onToggled: checked => page.setPower(checked)
    }

    MText {
        width: parent.width
        visible: page.available && page.on && page.adapter !== null
        role: "bodyMedium"
        color: M3.surfaceVariantContent
        wrapMode: Text.Wrap
        text: page.adapter ? i18n("Visible to nearby devices as “%1” while this page is open.", page.adapter.name) : ""
    }

    Group {
        title: i18n("Your devices")
        visible: page.available && page.on
        note: page.paired.length === 0 ? i18n("No paired devices yet.") : ""

        Repeater {
            model: page.paired
            delegate: ListItem {
                id: deviceRow
                required property var modelData
                title: modelData.name
                subtitle: page.deviceStatus(modelData)
                icon: page.deviceIcon(modelData)
                accent: modelData.connected ? 0 : -1
                iconStyle: modelData.connected ? "circle" : "plain"
                trailing: Component {
                    RowLayout {
                        spacing: 4
                        QQC2.BusyIndicator {
                            id: busy
                            visible: false
                            running: visible
                            implicitWidth: 24
                            implicitHeight: 24
                        }
                        IconButton {
                            iconName: "configure"
                            text: i18n("Device details")
                            onClicked: page.open("BluetoothDevicePage.qml", { device: deviceRow.modelData })
                        }
                    }
                }
                onClicked: {
                    if (modelData.connected) {
                        modelData.disconnectFromDevice();
                    } else {
                        modelData.connectToDevice();
                    }
                }
            }
        }
    }

    Group {
        visible: page.available && page.on

        ListItem {
            title: i18n("Pair a new device")
            subtitle: i18n("Headphones, speakers, keyboards, mice, phones")
            icon: "list-add"
            accent: 0
            chevron: true
            onClicked: page.open("BluetoothPairPage.qml", {})
        }
    }

    Component.onCompleted: {
        if (adapter && on) {
            adapter.discoverable = true;
        }
    }
    Component.onDestruction: {
        if (adapter) {
            adapter.discoverable = false;
        }
    }
}
