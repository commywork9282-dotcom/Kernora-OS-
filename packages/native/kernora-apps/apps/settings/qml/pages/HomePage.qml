/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.notificationmanager as NotificationManager
import org.kernora.m3
import org.kernora.ui
import org.kernora.system
import "../components"

SettingsPage {
    id: page

    title: i18n("Home settings")

    property int iconSize: 3
    property int sortMode: 0
    property bool locked: false
    property bool desktopFound: false

    NotificationManager.Settings {
        id: notifications
        live: true
    }

    ConfigEntry {
        id: addIcons
        file: "kernorarc"
        group: "Home"
        key: "addAppIcons"
        defaultValue: "true"
    }

    function readDesktop(): void {
        const script = "var list = desktops().filter(function (d) { return d.screen >= 0; }); "
            + "if (list.length === 0) { list = desktops(); } "
            + "list.sort(function (a, b) { return a.screen - b.screen; }); "
            + "var d = list[0]; var out = null; "
            + "if (d) { d.currentConfigGroup = ['General']; "
            + "out = { iconSize: d.readConfig('iconSize', 3), sortMode: d.readConfig('sortMode', 0), locked: d.readConfig('locked', false) }; } "
            + "print(JSON.stringify(out));";
        DBus.call("session", "org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell", "evaluateScript",
                  [{ type: "s", value: script }], (ok, result) => {
            let values = null;
            if (ok) {
                try {
                    values = JSON.parse(String(result).trim());
                } catch (error) {
                    values = null;
                }
            }
            page.desktopFound = values !== null;
            if (values !== null) {
                page.iconSize = Number(values.iconSize);
                page.sortMode = Number(values.sortMode);
                page.locked = values.locked === true || String(values.locked) === "true";
            }
        });
    }

    function writeDesktop(key: string, value: var): void {
        const literal = typeof value === "boolean" ? (value ? "true" : "false") : String(Math.round(value));
        DBus.call("session", "org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell", "evaluateScript",
                  [{ type: "s", value: "desktops().forEach(function (d) { d.currentConfigGroup = ['General']; "
                      + "d.writeConfig('" + key + "', " + literal + "); });" }],
                  ok => {
                      if (!ok) {
                          page.notify(i18n("The Home screen could not be changed."));
                          page.readDesktop();
                      }
                  });
    }

    Component.onCompleted: readDesktop()

    onVisibleChanged: {
        if (visible) {
            readDesktop();
        }
    }

    Group {
        ListItem {
            title: i18n("Notification dots")
            subtitle: notifications.badgesInTaskManager ? i18nc("notification dots", "On") : i18nc("notification dots", "Off")
            chevron: true
            onClicked: page.app.openCategory("notifications", "", {})
        }

        ListItem {
            title: i18n("Add app icons to Home screen")
            subtitle: i18n("For new apps")
            checkable: true
            checked: String(addIcons.value) === "true"
            onToggled: on => addIcons.value = on ? "true" : "false"
        }
    }

    Group {
        title: i18n("Icons on the Home screen")
        visible: page.desktopFound

        SliderItem {
            title: i18n("Icon size")
            from: 0
            to: 6
            stepSize: 1
            value: page.iconSize
            formatValue: v => {
                const units = Kirigami.Units.iconSizes;
                const sizes = [units.smallMedium, units.medium, units.large, units.huge,
                               units.large * 2, units.enormous, units.enormous * 2];
                return i18n("%1 px", sizes[Math.round(v)]);
            }
            onMoved: value => {
                const size = Math.round(value);
                if (size !== page.iconSize) {
                    page.iconSize = size;
                    page.writeDesktop("iconSize", size);
                }
            }
        }

        ChoiceItem {
            title: i18n("Sort icons")
            options: [
                { value: -1, label: i18n("Manually") },
                { value: 0, label: i18n("By name") },
                { value: 1, label: i18n("By size") },
                { value: 6, label: i18n("By type") },
                { value: 2, label: i18n("By date") }
            ]
            currentValue: page.sortMode
            subtitle: {
                const option = options.find(o => o.value === currentValue);
                return option ? option.label : "";
            }
            onSelected: value => {
                page.sortMode = value;
                page.writeDesktop("sortMode", value);
            }
        }

        ListItem {
            title: i18n("Lock icons in place")
            subtitle: i18n("Icons can't be moved by dragging")
            checkable: true
            checked: page.locked
            onToggled: on => {
                page.locked = on;
                page.writeDesktop("locked", on);
            }
        }
    }
}
