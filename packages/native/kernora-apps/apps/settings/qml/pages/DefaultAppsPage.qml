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

    title: i18n("Default apps")
    subtitle: i18n("The apps that open links, folders and files.")

    property int revision: 0

    Group {
        Repeater {
            model: DefaultApps.categories()

            delegate: ChoiceItem {
                id: row
                required property var modelData
                readonly property var current: { page.revision; return DefaultApps.currentApplication(modelData.id); }
                title: modelData.label
                subtitle: current.name || i18n("Not set")
                dialogTitle: modelData.label
                leading: Component {
                    AppIcon {
                        name: row.current.icon || ""
                    }
                }
                options: DefaultApps.candidates(modelData.id).map(app => ({ value: app.storageId, label: app.name, appIcon: app.icon }))
                currentValue: current.storageId || ""
                onSelected: value => {
                    DefaultApps.setDefault(modelData.id, value);
                    page.revision += 1;
                }
            }
        }
    }
}
