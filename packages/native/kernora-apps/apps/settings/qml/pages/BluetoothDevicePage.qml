/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kernora.m3
import org.kernora.ui
import "../components"

SettingsPage {
    id: page

    property var device

    title: device ? device.name : ""
    subtitle: device ? (device.connected ? i18n("Connected") : i18n("Not connected")) : ""

    RowLayout {
        width: parent.width
        spacing: 12
        QQC2.Button {
            text: page.device && page.device.connected ? i18n("Disconnect") : i18n("Connect")
            highlighted: page.device && !page.device.connected
            onClicked: page.device.connected ? page.device.disconnectFromDevice() : page.device.connectToDevice()
        }
        QQC2.Button {
            text: i18n("Forget")
            icon.name: "user-trash"
            onClicked: forgetDialog.open()
        }
        Item { Layout.fillWidth: true }
    }

    Group {
        title: i18n("Device")

        ListItem {
            title: i18n("Name")
            subtitle: page.device ? page.device.name : ""
            icon: "document-edit"
            iconStyle: "plain"
            chevron: true
            onClicked: renameDialog.open()
        }
        ListItem {
            title: i18n("Battery")
            visible: page.device && page.device.battery
            interactive: false
            value: page.device && page.device.battery ? i18n("%1%", page.device.battery.percentage) : ""
            icon: "battery-full"
            iconStyle: "plain"
        }
        ListItem {
            title: i18n("Connect automatically")
            subtitle: i18n("Let the device connect without asking")
            icon: "network-connect"
            iconStyle: "plain"
            checkable: true
            checked: page.device ? page.device.trusted : false
            onToggled: on => page.device.trusted = on
        }
        ListItem {
            title: i18n("Address")
            interactive: false
            value: page.device ? page.device.address : ""
            icon: "help-about"
            iconStyle: "plain"
        }
    }

    Dialog {
        id: renameDialog
        title: i18n("Rename device")
        acceptText: i18n("Rename")
        acceptEnabled: nameField.text.trim().length > 0
        onOpened: {
            nameField.text = page.device.name;
            nameField.forceActiveFocus();
        }
        onAccepted: page.device.name = nameField.text.trim()
        InputField {
            id: nameField
            Layout.fillWidth: true
            label: i18n("Name")
            onAccepted: renameDialog.accept()
        }
    }

    Dialog {
        id: forgetDialog
        icon: "user-trash"
        title: i18n("Forget this device?")
        text: i18n("To use it again you have to pair it again.")
        acceptText: i18n("Forget")
        destructive: true
        onAccepted: {
            const adapter = page.device.adapter;
            adapter.removeDevice(page.device);
            page.back();
        }
    }
}
