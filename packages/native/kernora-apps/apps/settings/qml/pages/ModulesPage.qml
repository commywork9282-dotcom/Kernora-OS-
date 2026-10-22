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

    title: i18n("More settings")
    subtitle: i18n("Every option of the system, including the rarely used ones.")

    readonly property var internal: ["kcm_activities", "kcm_kded", "kcm_feedback", "kwincompositing",
                                     "kcm_kgamma", "kcm_qtquicksettings", "kcm_landingpage", "kcm_kwintabbox"]
    readonly property var modules: Process.settingsModules()
        .filter(m => !internal.includes(m.id) && catalog.resolve(m.id) === null)

    Catalog {
        id: catalog
    }
    readonly property var shown: {
        const query = filter.text.trim().toLocaleLowerCase();
        if (query.length === 0) {
            return modules;
        }
        return modules.filter(m => (m.name + " " + m.description).toLocaleLowerCase().includes(query));
    }

    SearchField {
        id: filter
        width: parent.width
        placeholderText: i18n("Filter")
    }

    Group {
        note: page.shown.length === 0 ? i18n("Nothing matches.") : ""

        Repeater {
            model: page.shown
            delegate: ListItem {
                required property var modelData
                title: modelData.name
                subtitle: modelData.description
                icon: modelData.icon || "preferences-other"
                iconStyle: "plain"
                maximumSubtitleLines: 1
                chevron: true
                onClicked: Process.openModule(modelData.id)
            }
        }
    }
}
