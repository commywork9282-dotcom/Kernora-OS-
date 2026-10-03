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

    readonly property var found: {
        const all = Array.from(manager.devices);
        return all.filter(d => !d.paired && d.name.length > 0)
                  .sort((a, b) => b.rssi - a.rssi);
    }

    Component.onCompleted: {
        if (adapter && !adapter.discovering) {
            adapter.startDiscovery();
        }
    }
    Component.onDestruction: {
        if (adapter && adapter.discovering) {
            adapter.stopDiscovery();
        }
    }

    function pair(device: var): void {
        pairing = device.address;
        failed = "";
        const call = device.pair();
        call.finished.connect(() => {
            pairing = "";
            if (call.error) {
                failed = device.address;
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
    }

    Group {
        title: i18n("Available devices")
        note: page.found.length === 0 ? i18n("No devices found yet.") : ""

        Repeater {
            model: page.found
            delegate: ListItem {
                id: foundRow
                required property var modelData
                title: modelData.name
                subtitle: page.pairing === modelData.address ? i18n("Pairing…")
                    : page.failed === modelData.address ? i18n("Pairing failed. Try again.") : modelData.address
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
