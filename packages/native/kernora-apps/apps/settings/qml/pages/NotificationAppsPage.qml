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

    title: i18n("App notifications")
    subtitle: i18n("Apps are listed after they have sent a notification.")

    NotificationManager.Settings {
        id: settings
        live: true
    }

    property int revision: 0

    readonly property var apps: {
        const result = [];
        for (const entry of settings.knownApplications) {
            const info = Process.application(entry);
            if (info.name) {
                result.push({ entry: entry, name: info.name, icon: info.icon });
            }
        }
        return result.sort((a, b) => a.name.localeCompare(b.name));
    }

    function has(entry: string, flag: int): bool {
        page.revision;
        return (settings.applicationBehavior(entry) & flag) !== 0;
    }

    function setFlag(entry: string, flag: int, on: bool): void {
        let behavior = settings.applicationBehavior(entry);
        behavior = on ? (behavior | flag) : (behavior & ~flag);
        settings.setApplicationBehavior(entry, behavior);
        settings.save();
        revision += 1;
    }

    EmptyState {
        visible: page.apps.length === 0
        icon: "notifications"
        title: i18n("No apps yet")
        text: i18n("When an app sends a notification, you can choose here how it may notify you.")
    }

    Group {
        visible: page.apps.length > 0

        Repeater {
            model: page.apps
            delegate: ListItem {
                id: appRow
                required property var modelData
                title: modelData.name
                subtitle: page.has(modelData.entry, NotificationManager.Settings.ShowPopups) ? i18n("Pop-ups allowed") : i18n("Only in the history")
                leading: Component {
                    AppIcon {
                        name: appRow.modelData.icon
                    }
                }
                checkable: true
                checked: page.has(modelData.entry, NotificationManager.Settings.ShowPopups)
                onToggled: on => page.setFlag(modelData.entry, NotificationManager.Settings.ShowPopups, on)
            }
        }
    }
}
