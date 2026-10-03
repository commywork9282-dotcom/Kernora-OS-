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

    title: i18n("Language & region")

    property bool relogin: false
    readonly property var samples: Locales.formatSamples(Locales.region)

    Connections {
        target: Locales
        function onNeedsRelogin() {
            page.relogin = true;
        }
        function onFailed(message) {
            page.notify(message);
        }
    }

    Banner {
        width: parent.width
        visible: page.relogin
        icon: "system-log-out"
        title: i18n("Log out to finish")
        text: i18n("Apps use the new language and formats after you log in again.")
        actionText: i18n("Log out")
        onActionTriggered: DBus.call("session", "org.kde.LogoutPrompt", "/LogoutPrompt", "org.kde.LogoutPrompt", "promptLogout", [], null)
    }

    LinearProgress {
        width: parent.width
        visible: Locales.busy
        indeterminate: true
    }

    Group {
        ChoiceItem {
            title: i18n("Language")
            icon: "preferences-desktop-locale"
            accent: 3
            enabled: !Locales.busy
            options: Locales.languages().map(l => ({ value: l.code, label: l.name, description: l.name !== l.englishName ? l.englishName : "" }))
            currentValue: Locales.language
            onSelected: value => Locales.setLanguage(value)
        }
        ChoiceItem {
            title: i18n("Region")
            subtitle: Locales.regionName(Locales.region)
            icon: "globe"
            accent: 3
            enabled: !Locales.busy
            dialogTitle: i18n("Formats of region")
            options: Locales.regions().map(r => ({ value: r.locale, label: r.name }))
            currentValue: Locales.region
            onSelected: value => Locales.setRegion(value)
        }
    }

    Group {
        title: i18n("Examples")

        ListItem { interactive: false; title: i18n("Date"); value: page.samples.date || ""; icon: "office-calendar"; iconStyle: "plain" }
        ListItem { interactive: false; title: i18n("Time"); value: page.samples.time || ""; icon: "clock"; iconStyle: "plain" }
        ListItem { interactive: false; title: i18n("Numbers"); value: page.samples.number || ""; icon: "text-x-generic"; iconStyle: "plain" }
        ListItem { interactive: false; title: i18n("Money"); value: page.samples.currency || ""; icon: "text-x-generic"; iconStyle: "plain" }
    }

    Group {
        ListItem {
            title: i18n("Keyboard layouts")
            icon: "input-keyboard"
            iconStyle: "plain"
            chevron: true
            onClicked: page.app.openCategory("input", "", {})
        }
        ListItem {
            title: i18n("Detailed formats")
            subtitle: i18n("Separate settings for numbers, time, currency and measurement units")
            icon: "configure"
            iconStyle: "plain"
            chevron: true
            onClicked: Process.openModule("kcm_regionandlang")
        }
    }
}
