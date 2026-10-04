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

    title: i18n("Advanced keyboard options")

    readonly property var groups: Locales.keyboardOptionGroups()
    readonly property var special: [
        { id: "Compose key", title: i18n("Compose key"), none: i18n("Off"), icon: "input-keyboard" },
        { id: "caps", title: i18n("Caps Lock"), icon: "format-text-uppercase" },
        { id: "lv3", title: i18n("Key for extra characters"), icon: "input-keyboard" },
        { id: "altwin", title: i18n("Alt and Meta keys"), icon: "input-keyboard" }
    ]

    function group(id: string): var {
        return groups.find(g => g.id === id) || null;
    }

    function active(group: var): var {
        if (!group) {
            return [];
        }
        return group.options.filter(o => Locales.keyboardOptions.includes(o.id));
    }

    readonly property int activeCount: groups.reduce((sum, g) => sum + active(g).length, 0)

    InputField {
        width: parent.width
        label: i18n("Try your keys here")
    }

    Group {
        ChoiceItem {
            title: i18n("Keyboard model")
            icon: "input-keyboard"
            iconStyle: "plain"
            options: Locales.keyboardModels().map(m => ({ value: m.id, label: m.name }))
            currentValue: Locales.keyboardModel
            onSelected: value => Locales.setKeyboardModel(value)
        }
    }

    Group {
        title: i18n("Special keys")

        Repeater {
            model: page.special
            delegate: ChoiceItem {
                id: choice
                required property var modelData
                readonly property var xkbGroup: page.group(modelData.id)
                readonly property var chosen: page.active(xkbGroup)
                visible: xkbGroup !== null
                title: modelData.title
                subtitle: chosen.length > 0 ? chosen.map(o => o.name).join(", ") : (modelData.none || i18n("Default"))
                icon: modelData.icon
                iconStyle: "plain"
                dialogTitle: xkbGroup ? xkbGroup.name : modelData.title
                options: [{ value: "", label: modelData.none || i18n("Default") }]
                         .concat(xkbGroup ? xkbGroup.options.map(o => ({ value: o.id, label: o.name })) : [])
                currentValue: chosen.length > 0 ? chosen[0].id : ""
                onSelected: value => Locales.setKeyboardGroupChoice(modelData.id, value)
            }
        }
    }

    Group {
        title: i18n("All options")
        note: page.activeCount > 0 ? i18np("One option is on.", "%1 options are on.", page.activeCount) : ""

        Repeater {
            model: page.groups
            delegate: ListItem {
                required property var modelData
                readonly property var enabledOptions: page.active(modelData)
                title: modelData.name
                subtitle: enabledOptions.map(o => o.name).join(", ")
                maximumSubtitleLines: 1
                chevron: true
                onClicked: page.open("KeyboardOptionGroupPage.qml", { group: modelData })
            }
        }
    }

    Group {
        visible: page.activeCount > 0

        ListItem {
            title: i18n("Turn off all options")
            icon: "edit-undo"
            iconStyle: "plain"
            destructive: true
            onClicked: {
                for (const g of page.groups.filter(g => page.active(g).length > 0)) {
                    Locales.setKeyboardGroupChoice(g.id, "");
                }
            }
        }
    }
}
