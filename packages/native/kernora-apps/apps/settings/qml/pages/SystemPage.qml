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

    title: i18n("System")

    property var timezone: ""
    Component.onCompleted: {
        DBus.getProperty("system", "org.freedesktop.timedate1", "/org/freedesktop/timedate1", "org.freedesktop.timedate1", "Timezone",
                         (ok, value) => page.timezone = ok ? value : "");
    }

    ConfigEntry { id: loginMode; file: "ksmserverrc"; group: "General"; key: "loginMode"; defaultValue: "emptySession" }

    Group {
        ListItem {
            title: i18n("Language & region")
            subtitle: Locales.languageName(Locales.language) + " · " + Locales.regionName(Locales.region)
            icon: "preferences-desktop-locale"
            accent: 3
            chevron: true
            onClicked: page.open("LanguagePage.qml", {})
        }
        ListItem {
            title: i18n("Date & time")
            subtitle: String(page.timezone).replace(/_/g, " ")
            icon: "preferences-system-time"
            accent: 3
            chevron: true
            onClicked: page.open("DateTimePage.qml", {})
        }
        ListItem {
            title: i18n("Software updates")
            subtitle: Updates.state === Updates.UpdatesAvailable
                ? i18np("%1 update available", "%1 updates available", Updates.packages.length)
                : i18n("Security fixes and new versions")
            icon: "system-software-update"
            accent: 1
            chevron: true
            onClicked: page.open("UpdatesPage.qml", {})
        }
        ListItem {
            visible: !SystemInfo.live
            title: i18n("Drivers")
            subtitle: i18n("Graphics card drivers")
            icon: "cpu"
            accent: 1
            chevron: true
            onClicked: page.open("DriversPage.qml", {})
        }
        ListItem {
            title: i18n("Storage")
            subtitle: i18n("Free space, trash")
            icon: "drive-harddisk"
            accent: 1
            chevron: true
            onClicked: page.open("StoragePage.qml", {})
        }
        ListItem {
            title: i18n("Bring files from Windows")
            subtitle: i18n("Documents, pictures, wallpaper, bookmarks")
            icon: "folder-download"
            accent: 2
            chevron: true
            onClicked: page.open("MigratePage.qml", {})
        }
    }

    Group {
        title: i18n("Session")

        ChoiceItem {
            title: i18n("When you log in")
            icon: "system-run"
            iconStyle: "plain"
            options: [
                { value: "emptySession", label: i18n("Start with an empty desktop") },
                { value: "restorePreviousLogout", label: i18n("Reopen the apps that were open") }
            ]
            currentValue: loginMode.value === "restoreSavedSession" ? "restorePreviousLogout" : loginMode.value
            onSelected: value => loginMode.value = value
        }
    }

    Group {
        title: i18n("More")

        ListItem {
            title: i18n("More settings")
            subtitle: i18n("Printers, shortcuts, fonts and every other option")
            icon: "preferences-other"
            iconStyle: "plain"
            chevron: true
            onClicked: page.open("ModulesPage.qml", {})
        }
        ListItem {
            title: i18n("About Lumo")
            icon: "help-about"
            iconStyle: "plain"
            chevron: true
            onClicked: page.app.openCategory("about", "", {})
        }
    }
}
