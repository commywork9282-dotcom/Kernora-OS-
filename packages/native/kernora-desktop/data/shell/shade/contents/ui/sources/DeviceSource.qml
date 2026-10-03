/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.notification
import org.kde.plasma.private.devicenotifier as DN

Item {
    id: root

    property bool settled: false
    Timer {
        interval: 5000
        running: true
        onTriggered: root.settled = true
    }

    DN.DeviceFilterControl {
        id: devices
        filterType: DN.DeviceFilterControl.Removable

        onLastUdiChanged: {
            if (root.settled && lastDeviceAdded && lastUdi.length > 0) {
                announceTimer.udi = lastUdi;
                announceTimer.restart();
            }
        }
    }

    Instantiator {
        id: rows
        model: devices
        delegate: QtObject {
            required property string deviceUdi
            required property string deviceDescription
            required property string deviceIcon
            required property string deviceSizeText
            required property var deviceActions
        }
        onObjectRemoved: (index, object) => {
            if (object.deviceUdi === notification.udi) {
                notification.close();
                notification.udi = "";
            }
        }
    }

    function deviceFor(udi: string): QtObject {
        for (let i = 0; i < rows.count; ++i) {
            const row = rows.objectAt(i);
            if (row && row.deviceUdi === udi) {
                return row;
            }
        }
        return null;
    }

    Timer {
        id: announceTimer
        property string udi
        interval: 300
        onTriggered: root.announce(udi)
    }

    function announce(udi: string): void {
        const device = deviceFor(udi);
        if (!device) {
            return;
        }
        const memoryCard = device.deviceIcon.startsWith("media-flash");
        notification.udi = udi;
        notification.title = memoryCard ? i18n("Memory card connected") : i18n("USB drive connected");
        notification.text = device.deviceSizeText.length > 0
            ? i18nc("drive name · size", "%1 · %2", device.deviceDescription, device.deviceSizeText)
            : device.deviceDescription;
        notification.iconName = device.deviceIcon;
        notification.sendEvent();
    }

    function open(udi: string): void {
        const device = deviceFor(udi);
        if (device && device.deviceActions) {
            device.deviceActions.actionTriggered(device.deviceActions.defaultActionName);
        }
    }

    Notification {
        id: notification
        property string udi
        componentName: "kernora-devices"
        eventId: "storageAdded"
        autoDelete: false
        defaultAction: NotificationAction {
            label: i18n("Open")
            onActivated: root.open(notification.udi)
        }
        actions: [
            NotificationAction {
                label: i18n("Open")
                onActivated: root.open(notification.udi)
            }
        ]
    }
}
