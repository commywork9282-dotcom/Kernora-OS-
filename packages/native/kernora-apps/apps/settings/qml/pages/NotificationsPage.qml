/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.notificationmanager as NotificationManager
import org.kernora.m3
import org.kernora.ui
import org.kernora.system
import "../components"

SettingsPage {
    id: page

    title: i18n("Notifications")

    NotificationManager.Settings {
        id: settings
        live: true
    }

    property double now: Date.now()
    Timer {
        interval: 30000
        running: page.visible
        repeat: true
        onTriggered: page.now = Date.now()
    }

    readonly property var until: settings.notificationsInhibitedUntil
    readonly property bool timedDnd: !!until && !isNaN(until.getTime()) && now < until.getTime()
    readonly property bool dnd: timedDnd || settings.notificationsInhibitedByApplication

    function setDnd(on: bool, minutes: int): void {
        if (on) {
            const date = new Date();
            if (minutes > 0) {
                date.setTime(date.getTime() + minutes * 60000);
            } else {
                date.setFullYear(date.getFullYear() + 1);
            }
            settings.notificationsInhibitedUntil = date;
        } else {
            settings.notificationsInhibitedUntil = undefined;
            settings.revokeApplicationInhibitions();
        }
        settings.save();
        now = Date.now();
    }

    function set(property: string, value: var): void {
        settings[property] = value;
        settings.save();
    }

    readonly property string dndSubtitle: {
        if (!dnd) {
            return i18n("Off");
        }
        if (settings.notificationsInhibitedByApplication && !timedDnd) {
            return i18n("Turned on by an app");
        }
        if (until.getFullYear() > new Date().getFullYear()) {
            return i18n("On until you turn it off");
        }
        return i18n("On until %1", until.toLocaleTimeString(Qt.locale(), Locale.ShortFormat));
    }

    HeroSwitch {
        width: parent.width
        title: i18n("Do Not Disturb")
        checked: page.dnd
        onToggled: checked => page.setDnd(checked, 0)
    }

    Group {
        ListItem {
            title: i18n("Status")
            subtitle: page.dndSubtitle
            icon: "notifications-disabled"
            accent: 4
            interactive: false
        }
        ListItem {
            title: i18n("For one hour")
            icon: "clock"
            iconStyle: "plain"
            visible: !page.dnd
            chevron: true
            onClicked: page.setDnd(true, 60)
        }
        ListItem {
            title: i18n("Until tomorrow morning")
            icon: "night-light"
            iconStyle: "plain"
            visible: !page.dnd
            chevron: true
            onClicked: {
                const morning = new Date();
                morning.setDate(morning.getDate() + 1);
                morning.setHours(8, 0, 0, 0);
                page.setDnd(true, Math.round((morning.getTime() - Date.now()) / 60000));
            }
        }
        ListItem {
            title: i18n("Show critical notifications")
            subtitle: i18n("Even while Do Not Disturb is on")
            icon: "dialog-warning"
            iconStyle: "plain"
            checkable: true
            checked: settings.criticalPopupsInDoNotDisturbMode
            onToggled: on => page.set("criticalPopupsInDoNotDisturbMode", on)
        }
        ListItem {
            title: i18n("Quiet while sharing the screen")
            subtitle: i18n("Turn on Do Not Disturb while screens are mirrored or shared")
            icon: "video-display"
            iconStyle: "plain"
            checkable: true
            checked: settings.inhibitNotificationsWhenScreensMirrored
            onToggled: on => {
                settings.inhibitNotificationsWhenScreensMirrored = on;
                settings.inhibitNotificationsWhenScreenSharing = on;
                settings.save();
            }
        }
    }

    Group {
        title: i18n("Pop-ups")

        ChoiceItem {
            title: i18n("Position")
            icon: "window"
            iconStyle: "plain"
            options: [
                { value: NotificationManager.Settings.CloseToWidget, label: i18n("Near the notification bell") },
                { value: NotificationManager.Settings.TopRight, label: i18n("Top right") },
                { value: NotificationManager.Settings.TopCenter, label: i18n("Top centre") },
                { value: NotificationManager.Settings.TopLeft, label: i18n("Top left") },
                { value: NotificationManager.Settings.BottomRight, label: i18n("Bottom right") },
                { value: NotificationManager.Settings.BottomCenter, label: i18n("Bottom centre") },
                { value: NotificationManager.Settings.BottomLeft, label: i18n("Bottom left") }
            ]
            currentValue: settings.popupPosition
            onSelected: value => page.set("popupPosition", value)
        }
        ChoiceItem {
            title: i18n("Hide pop-ups after")
            icon: "clock"
            iconStyle: "plain"
            options: [3, 5, 7, 10, 15, 30].map(s => ({ value: s * 1000, label: i18np("%1 second", "%1 seconds", s) }))
            currentValue: settings.popupTimeout
            onSelected: value => page.set("popupTimeout", value)
        }
        ListItem {
            title: i18n("Low-priority notifications")
            subtitle: i18n("Show pop-ups for less important messages")
            icon: "notifications"
            iconStyle: "plain"
            checkable: true
            checked: settings.lowPriorityPopups
            onToggled: on => page.set("lowPriorityPopups", on)
        }
        ListItem {
            title: i18n("Progress of file transfers")
            subtitle: i18n("Show copying and downloads as notifications")
            icon: "folder-download"
            iconStyle: "plain"
            checkable: true
            checked: settings.jobsInNotifications
            onToggled: on => page.set("jobsInNotifications", on)
        }
        ListItem {
            title: i18n("Notification sounds")
            icon: "preferences-desktop-sound"
            iconStyle: "plain"
            checkable: true
            checked: !settings.notificationSoundsInhibited
            onToggled: on => page.set("notificationSoundsInhibited", !on)
        }
        ListItem {
            title: i18n("Badges on app icons")
            subtitle: i18n("Count unread notifications on the taskbar")
            icon: "notification-active"
            iconStyle: "plain"
            checkable: true
            checked: settings.badgesInTaskManager
            onToggled: on => page.set("badgesInTaskManager", on)
        }
    }

    Group {
        title: i18n("Apps")

        ListItem {
            title: i18n("App notifications")
            subtitle: i18n("Choose which apps may show notifications")
            icon: "view-app-grid"
            accent: 4
            chevron: true
            onClicked: page.open("NotificationAppsPage.qml", {})
        }
    }
}
