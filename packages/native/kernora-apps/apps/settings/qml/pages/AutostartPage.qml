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

    title: i18n("Startup apps")
    subtitle: i18n("These apps start when you log in.")

    property int revision: 0
    readonly property var entries: { revision; return Autostart.entries(); }

    EmptyState {
        visible: page.entries.length === 0
        icon: "system-run"
        title: i18n("Nothing starts at login")
        text: i18n("Add an app to have it ready as soon as you log in.")
    }

    Group {
        visible: page.entries.length > 0

        Repeater {
            model: page.entries
            delegate: ListItem {
                id: row
                required property var modelData
                title: modelData.name
                subtitle: modelData.comment || ""
                leading: Component {
                    AppIcon {
                        name: row.modelData.icon || ""
                    }
                }
                trailing: Component {
                    IconButton {
                        visible: row.modelData.user
                        iconName: "user-trash"
                        text: i18n("Remove")
                        onClicked: {
                            Autostart.remove(row.modelData.id);
                            page.revision += 1;
                        }
                    }
                }
                checkable: true
                checked: modelData.enabled
                onToggled: on => {
                    Autostart.setEnabled(modelData.id, on);
                    page.revision += 1;
                }
            }
        }
    }

    Group {
        ListItem {
            title: i18n("Add an app")
            icon: "list-add"
            accent: 2
            chevron: true
            onClicked: addDialog.open()
        }
    }

    ChoiceDialog {
        id: addDialog
        title: i18n("Start at login")
        searchable: true
        options: addDialog.visible ? Autostart.applications().map(app => ({ value: app.storageId, label: app.name, appIcon: app.icon })) : []
        onChosen: value => {
            Autostart.add(value);
            page.revision += 1;
        }
    }
}
