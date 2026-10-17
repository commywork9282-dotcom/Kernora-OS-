/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.bluezqt as BluezQt
import "m3"

ColumnLayout {
    id: panel

    required property QtObject backend
    signal back()
    signal requestClose()

    spacing: 12

    readonly property var manager: BluezQt.Manager
    readonly property bool available: manager.adapters.length > 0 || manager.bluetoothBlocked
    readonly property bool on: manager.bluetoothOperational
    readonly property var paired: Array.from(manager.devices)
        .filter(device => device.paired)
        .sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
    property var pending: ({})

    function setPower(enable: bool): void {
        manager.bluetoothBlocked = !enable;
        for (const adapter of Array.from(manager.adapters)) {
            adapter.powered = enable;
        }
    }

    function icon(device: var): string {
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
        }
        return "preferences-system-bluetooth";
    }

    function status(device: var): string {
        if (panel.pending[device.address]) {
            return device.connected ? i18n("Disconnecting…") : i18n("Connecting…");
        }
        const parts = [device.connected ? i18n("Connected") : i18n("Not connected")];
        if (device.battery) {
            parts.push(i18n("%1% battery", device.battery.percentage));
        }
        return parts.join(" · ");
    }

    function toggle(device: var): void {
        const address = device.address;
        const busy = Object.assign({}, panel.pending);
        busy[address] = true;
        panel.pending = busy;
        const call = device.connected ? device.disconnectFromDevice() : device.connectToDevice();
        const done = () => {
            const left = Object.assign({}, panel.pending);
            delete left[address];
            panel.pending = left;
        };
        if (call && call.finished) {
            call.finished.connect(done);
        } else {
            done();
        }
    }

    PanelHeader {
        Layout.fillWidth: true
        title: i18n("Bluetooth")
        switchVisible: panel.available
        switchChecked: panel.on
        onBack: panel.back()
        onSwitched: checked => panel.setPower(checked)
    }

    MText {
        Layout.fillWidth: true
        Layout.leftMargin: 8
        visible: !panel.available || !panel.on
        role: "bodyMedium"
        color: M3.surfaceVariantContent
        wrapMode: Text.Wrap
        text: !panel.available ? i18n("This computer has no Bluetooth.") : i18n("Turn Bluetooth on to use your devices.")
    }

    PanelGroup {
        Layout.fillWidth: true
        visible: panel.available && panel.on

        MText {
            visible: panel.paired.length === 0
            width: parent.width
            topPadding: 12
            bottomPadding: 12
            horizontalAlignment: Text.AlignHCenter
            role: "bodyMedium"
            color: M3.surfaceVariantContent
            text: i18n("No paired devices yet.")
        }

        Repeater {
            model: panel.paired
            delegate: PanelRow {
                required property var modelData
                width: parent.width
                icon: panel.icon(modelData)
                title: modelData.name
                subtitle: panel.status(modelData)
                active: modelData.connected
                busy: panel.pending[modelData.address] === true
                onClicked: panel.toggle(modelData)
            }
        }
    }

    MButton {
        Layout.alignment: Qt.AlignRight
        visible: panel.available
        variant: "tonal"
        icon: "list-add"
        text: i18n("Pair new device")
        onClicked: {
            panel.backend.openSettings("bluetooth");
            panel.requestClose();
        }
    }
}
