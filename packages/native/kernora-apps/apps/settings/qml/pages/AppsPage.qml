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

    title: i18n("Apps")

    property int revision: 0
    readonly property var browser: { revision; return DefaultApps.currentApplication("browser"); }
    readonly property var startup: { revision; return Autostart.entries().filter(e => e.enabled); }

    QQC2.StackView.onActivated: page.revision += 1

    Group {
        ListItem {
            title: i18n("Default apps")
            subtitle: page.browser.name ? i18n("Browser: %1", page.browser.name) : i18n("Browser, email, files and media")
            icon: "preferences-desktop-default-applications"
            accent: 2
            chevron: true
            onClicked: page.open("DefaultAppsPage.qml", {})
        }
        ListItem {
            title: i18n("Startup apps")
            subtitle: page.startup.length === 0 ? i18n("Nothing starts at login")
                : i18np("%1 app starts at login", "%1 apps start at login", page.startup.length)
            icon: "system-run"
            accent: 2
            chevron: true
            onClicked: page.open("AutostartPage.qml", {})
        }
        ListItem {
            title: i18n("App notifications")
            subtitle: i18n("Which apps may show pop-ups")
            icon: "preferences-desktop-notification"
            accent: 4
            chevron: true
            onClicked: page.open("NotificationAppsPage.qml", {})
        }
    }

    Group {
        title: i18n("More")

        ListItem {
            title: i18n("File types")
            subtitle: i18n("Choose an app for any kind of file")
            icon: "preferences-desktop-filetype-association"
            iconStyle: "plain"
            chevron: true
            onClicked: Process.openModule("kcm_filetypes")
        }
        ListItem {
            title: i18n("Keyboard shortcuts")
            subtitle: i18n("Shortcuts for apps and the desktop")
            icon: "preferences-desktop-keyboard-shortcut"
            iconStyle: "plain"
            chevron: true
            onClicked: Process.openModule("kcm_keys")
        }
    }
}
