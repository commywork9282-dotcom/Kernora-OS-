/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kernora.m3
import org.kernora.ui
import org.kernora.system
import "../components"

SettingsPage {
    id: page

    title: i18n("Detailed formats")
    subtitle: i18n("Each format follows the region unless you choose another one")

    property bool relogin: false
    readonly property var regions: Locales.regions()

    readonly property var categories: [
        { key: "LC_NUMERIC", title: i18n("Numbers"), icon: "format-number-percent" },
        { key: "LC_TIME", title: i18n("Date and time"), icon: "clock" },
        { key: "LC_MONETARY", title: i18n("Money"), icon: "wallet-open" },
        { key: "LC_MEASUREMENT", title: i18n("Units of measurement"), icon: "measure" },
        { key: "LC_PAPER", title: i18n("Paper size"), icon: "document-print" }
    ]

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
        Repeater {
            model: page.categories
            delegate: ChoiceItem {
                id: item
                required property var modelData
                readonly property string chosen: Locales.formats[modelData.key] || ""
                readonly property string effective: chosen.length > 0 ? chosen : Locales.region
                title: modelData.title
                subtitle: Locales.formatSample(modelData.key, effective) + " · "
                          + (chosen.length > 0 ? Locales.regionName(chosen) : i18n("As in the region"))
                icon: modelData.icon
                iconStyle: "plain"
                enabled: !Locales.busy
                options: [{ value: "", label: i18n("As in the region"), description: Locales.regionName(Locales.region) + " · " + Locales.formatSample(modelData.key, Locales.region) }]
                         .concat(page.regions.map(r => ({ value: r.locale, label: r.name, description: Locales.formatSample(modelData.key, r.locale) })))
                currentValue: chosen
                onSelected: value => Locales.setFormat(modelData.key, value)
            }
        }
    }
}
