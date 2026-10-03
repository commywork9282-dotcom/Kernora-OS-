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

    title: i18n("Security & privacy")

    function isOn(entry: var): bool {
        return entry.value === true || entry.value === "true";
    }

    ConfigEntry { id: autolock; file: "kscreenlockerrc"; group: "Daemon"; key: "Autolock"; defaultValue: true }
    ConfigEntry { id: lockTimeout; file: "kscreenlockerrc"; group: "Daemon"; key: "Timeout"; defaultValue: 5 }
    ConfigEntry { id: lockOnResume; file: "kscreenlockerrc"; group: "Daemon"; key: "LockOnResume"; defaultValue: true }
    ConfigEntry { id: lockGrace; file: "kscreenlockerrc"; group: "Daemon"; key: "LockGrace"; defaultValue: 5 }

    function reconfigureLocker(): void {
        DBus.call("session", "org.freedesktop.ScreenSaver", "/ScreenSaver", "org.kde.screensaver", "configure", [], null);
    }

    Group {
        title: i18n("Screen lock")

        ChoiceItem {
            title: i18n("Lock the screen automatically")
            icon: "system-lock-screen"
            accent: 4
            options: [0, 1, 2, 5, 10, 15, 30, 60].map(m => ({
                value: m,
                label: m === 0 ? i18n("Never") : i18np("After %1 minute", "After %1 minutes", m)
            }))
            currentValue: page.isOn(autolock) ? Number(lockTimeout.value) : 0
            onSelected: value => {
                autolock.value = value > 0;
                if (value > 0) {
                    lockTimeout.value = value;
                }
                page.reconfigureLocker();
            }
        }
        ListItem {
            title: i18n("Lock after waking up")
            subtitle: i18n("Ask for the password when the computer wakes from sleep")
            icon: "system-suspend"
            iconStyle: "plain"
            checkable: true
            checked: page.isOn(lockOnResume)
            onToggled: on => {
                lockOnResume.value = on;
                page.reconfigureLocker();
            }
        }
        ChoiceItem {
            title: i18n("Unlock without a password for")
            icon: "clock"
            iconStyle: "plain"
            enabled: page.isOn(autolock)
            options: [0, 5, 15, 30, 60].map(s => ({
                value: s,
                label: s === 0 ? i18n("No time") : i18np("%1 second after locking", "%1 seconds after locking", s)
            }))
            currentValue: Number(lockGrace.value)
            onSelected: value => {
                lockGrace.value = value;
                page.reconfigureLocker();
            }
        }
        ListItem {
            title: i18n("Lock now")
            icon: "system-lock-screen"
            iconStyle: "plain"
            onClicked: DBus.call("session", "org.freedesktop.ScreenSaver", "/ScreenSaver", "org.freedesktop.ScreenSaver", "Lock", [], null)
        }
        ListItem {
            title: i18n("Change password")
            icon: "preferences-desktop-user-password"
            iconStyle: "plain"
            chevron: true
            onClicked: page.app.openCategory("account", "", {})
        }
    }

    ConfigEntry { id: indexing; file: "baloofilerc"; group: "Basic Settings"; key: "Indexing-Enabled"; defaultValue: true }
    ConfigEntry { id: basicIndexing; file: "baloofilerc"; group: "General"; key: "only basic indexing"; defaultValue: false }
    readonly property string balooctl: Process.findExecutable("balooctl6")

    Group {
        title: i18n("File search")
        visible: page.balooctl.length > 0
        note: i18n("The index stays on this computer. It lets search find files by name and by what they contain.")

        ListItem {
            title: i18n("Index files for search")
            icon: "preferences-desktop-baloo"
            accent: 0
            checkable: true
            checked: page.isOn(indexing)
            onToggled: on => {
                indexing.value = on;
                Process.run(page.balooctl, [on ? "enable" : "disable"], null);
            }
        }
        ListItem {
            title: i18n("Only file names")
            subtitle: i18n("Don't look inside documents")
            icon: "text-x-generic"
            iconStyle: "plain"
            enabled: page.isOn(indexing)
            checkable: true
            checked: page.isOn(basicIndexing)
            onToggled: on => {
                basicIndexing.value = on;
                Process.run(page.balooctl, ["config", "set", "contentIndexing", on ? "no" : "yes"], null);
            }
        }
    }

    ConfigEntry {
        id: remember
        file: "kactivitymanagerd-pluginsrc"
        group: "Plugin-org.kde.ActivityManager.Resources.Scoring"
        key: "what-to-remember"
        defaultValue: 0
    }

    function clearHistory(): void {
        DBus.call("session", "org.kde.ActivityManager", "/ActivityManager/Resources/Scoring",
                  "org.kde.ActivityManager.ResourcesScoring", "DeleteRecentStats",
                  [{ type: "s", value: ":any" }, { type: "i", value: 0 }, { type: "s", value: "everything" }], null);
        const data = Files.standardFolder("home").toString() + "/.local/share";
        Files.remove([data + "/RecentDocuments", data + "/recently-used.xbel"], null);
        page.notify(i18n("The history of recent files was cleared."));
    }

    Group {
        title: i18n("History")

        ListItem {
            title: i18n("Remember recently used files")
            subtitle: i18n("Show them in the launcher, in Files and in apps")
            icon: "document-open-recent"
            accent: 4
            checkable: true
            checked: Number(remember.value) !== 2
            onToggled: on => remember.value = on ? 0 : 2
        }
        ListItem {
            title: i18n("Clear history")
            subtitle: i18n("Forget recently used files and folders")
            icon: "edit-clear-history"
            iconStyle: "plain"
            destructive: true
            onClicked: clearDialog.open()
        }
    }

    Dialog {
        id: clearDialog
        icon: "user-trash"
        title: i18n("Clear history?")
        text: i18n("Lists of recently used files and folders are emptied. The files themselves stay.")
        acceptText: i18n("Clear")
        destructive: true
        onAccepted: page.clearHistory()
    }
}
