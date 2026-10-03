/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.notificationmanager as NotificationManager

Item {
    id: root

    NotificationManager.Settings {
        id: settings
    }

    property double now: Date.now()
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.now = Date.now()
    }

    readonly property bool available: NotificationManager.Server.valid
    readonly property bool on: {
        const until = settings.notificationsInhibitedUntil;
        const timed = until && !isNaN(until.getTime()) && now < until.getTime();
        return timed || settings.notificationsInhibitedByApplication;
    }

    function toggle(): void {
        if (on) {
            settings.notificationsInhibitedUntil = undefined;
            settings.revokeApplicationInhibitions();
        } else {
            const until = new Date();
            until.setFullYear(until.getFullYear() + 1);
            settings.notificationsInhibitedUntil = until;
        }
        settings.save();
        now = Date.now();
    }
}
