/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kernora.m3
import org.kernora.ui
import org.kernora.system
import "../components"

SettingsPage {
    id: page

    property string name
    property string uuid
    property string connectionPath
    property string devicePath
    property bool connected: false
    property bool wireless: false
    property var details: []
    property var handler

    title: name
    subtitle: connected ? i18n("Connected") : i18n("Saved network")

    readonly property var pairs: {
        const result = [];
        for (let i = 0; i + 1 < details.length; i += 2) {
            result.push({ label: details[i], value: details[i + 1] });
        }
        return result;
    }

    RowLayout {
        width: parent.width
        spacing: 12

        QQC2.Button {
            visible: page.connected
            text: i18n("Disconnect")
            icon.name: "network-disconnect"
            onClicked: {
                page.handler.deactivateConnection(page.connectionPath, page.devicePath);
                page.back();
            }
        }
        QQC2.Button {
            visible: !page.connected
            text: i18n("Connect")
            icon.name: "network-connect"
            highlighted: true
            onClicked: {
                page.handler.activateConnection(page.connectionPath, page.devicePath, "");
                page.back();
            }
        }
        QQC2.Button {
            visible: page.uuid.length > 0
            text: i18n("Forget")
            icon.name: "user-trash"
            onClicked: forgetDialog.open()
        }
        Item { Layout.fillWidth: true }
    }

    Group {
        title: i18n("Details")
        visible: page.pairs.length > 0

        Repeater {
            model: page.pairs
            delegate: ListItem {
                required property var modelData
                interactive: false
                title: modelData.label
                value: modelData.value
            }
        }
    }

    Group {
        title: i18n("Settings")

        ListItem {
            title: i18n("Edit connection")
            subtitle: i18n("Password, automatic connection, IP addresses, DNS")
            icon: "document-edit"
            iconStyle: "plain"
            chevron: true
            onClicked: Process.startDetached("kcmshell6", ["kcm_networkmanagement", "--args", "Uuid=" + page.uuid])
        }
    }

    Dialog {
        id: forgetDialog
        icon: "user-trash"
        title: i18n("Forget “%1”?", page.name)
        text: page.wireless
            ? i18n("The saved password is removed. You can connect again later by entering it.")
            : i18n("The saved settings of this connection are removed.")
        acceptText: i18n("Forget")
        destructive: true
        onAccepted: {
            page.handler.removeConnection(page.connectionPath);
            page.back();
        }
    }
}
