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
import "../components"

SettingsPage {
    id: page

    title: i18n("Pair a new device")
    subtitle: i18n("Make sure the device is in pairing mode and close by.")

    readonly property var manager: BluezQt.Manager
    readonly property var adapter: manager.usableAdapter
    property string pairing: ""
    property string failed: ""
    property string reason: ""

    readonly property var found: {
        const all = Array.from(manager.devices);
        return all.filter(d => !d.paired && d.name.length > 0)
                  .sort((a, b) => b.rssi - a.rssi);
    }

    Component.onCompleted: search()
    Component.onDestruction: {
        if (adapter && adapter.discovering) {
            adapter.stopDiscovery();
        }
    }

    function failureText(error: int): string {
        switch (error) {
        case BluezQt.PendingCall.AuthenticationFailed:
            return i18n("The pairing code was wrong. Try again.");
        case BluezQt.PendingCall.AuthenticationRejected:
        case BluezQt.PendingCall.AuthenticationCanceled:
            return i18n("Pairing was cancelled.");
        case BluezQt.PendingCall.AuthenticationTimeout:
            return i18n("The device didn't answer in time. Try again.");
        case BluezQt.PendingCall.ConnectionAttemptFailed:
            return i18n("Couldn't reach the device. Bring it closer and try again.");
        }
        return i18n("Pairing failed. Try again.");
    }

    function search(): void {
        if (adapter && !adapter.discovering) {
            adapter.startDiscovery();
        }
    }

    function pair(device: var): void {
        if (adapter && adapter.discovering) {
            adapter.stopDiscovery();
        }
        pairing = device.address;
        failed = "";
        reason = "";
        const call = device.pair();
        call.finished.connect(() => {
            pairing = "";
            if (call.error) {
                failed = device.address;
                reason = page.failureText(call.error);
                page.notify(i18n("Couldn't pair with %1", device.name));
                return;
            }
            device.trusted = true;
            device.connectToDevice();
            page.notify(i18n("Paired with %1", device.name));
            page.back();
        });
    }

    RowLayout {
        width: parent.width
        spacing: 16
        visible: page.adapter !== null

        LinearProgress {
            Layout.fillWidth: true
            indeterminate: page.adapter && page.adapter.discovering
            visible: indeterminate
        }
        MText {
            role: "labelLarge"
            color: M3.surfaceVariantContent
            text: page.adapter && page.adapter.discovering ? i18n("Searching…") : ""
        }
        Item {
            Layout.fillWidth: true
            visible: !(page.adapter && page.adapter.discovering)
        }
        QQC2.Button {
            visible: !(page.adapter && page.adapter.discovering) && page.pairing.length === 0
            text: i18n("Search again")
            flat: true
            onClicked: page.search()
        }
    }

    Group {
        title: i18n("Available devices")
        note: page.found.length === 0 ? i18n("No devices found yet.")
            : i18n("If the device asks for a code, Lumo shows it or asks you to type it.")

        Repeater {
            model: page.found
            delegate: ListItem {
                id: foundRow
                required property var modelData
                title: modelData.name
                subtitle: page.pairing === modelData.address ? i18n("Pairing…")
                    : page.failed === modelData.address ? page.reason : modelData.address
                icon: "preferences-system-bluetooth"
                iconStyle: "plain"
                enabled: page.pairing.length === 0 || page.pairing === modelData.address
                trailing: Component {
                    QQC2.BusyIndicator {
                        visible: page.pairing === foundRow.modelData.address
                        running: visible
                        implicitWidth: 24
                        implicitHeight: 24
                    }
                }
                onClicked: page.pair(modelData)
            }
        }
    }
}
