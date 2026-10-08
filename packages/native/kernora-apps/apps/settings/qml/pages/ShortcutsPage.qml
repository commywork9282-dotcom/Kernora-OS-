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

    title: i18n("Keyboard shortcuts")

    property var actions: []
    property bool loaded: false

    readonly property var groups: [
        { id: "kwin", title: i18n("Windows and desktops") },
        { id: "plasmashell", title: i18n("Desktop and panel") },
        { id: "org.kernora.screenshot.desktop", title: i18n("Screenshot") },
        { id: "org.kernora.terminal.desktop", title: i18n("Terminal") },
        { id: "mediacontrol", title: i18n("Media") },
        { id: "kmix", title: i18n("Volume") },
        { id: "KDE_Keyboard_Layout_Switcher", title: i18n("Keyboard layout") },
        { id: "org_kde_powerdevil", title: i18n("Power") },
        { id: "org.kde.kscreen.desktop", title: i18n("Screens") },
        { id: "kcm_touchpad", title: i18n("Touchpad") },
        { id: "kaccess", title: i18n("Accessibility") },
        { id: "org.kde.plasma.emojier.desktop", title: i18n("Emoji") },
        { id: "ksmserver", title: i18n("Session") }
    ]
    readonly property var hidden: ["ActivityManager", "org.kde.krunner.desktop", "systemsettings.desktop"]

    function groupTitle(component: string, friendly: string): string {
        const group = groups.find(g => g.id === component);
        return group ? group.title : friendly;
    }

    function load(): void {
        DBus.call("session", "org.kde.kglobalaccel", "/kglobalaccel", "org.kde.KGlobalAccel", "allComponents", [], (ok, paths) => {
            if (!ok) {
                page.loaded = true;
                return;
            }
            const found = [];
            let pending = paths.length;
            for (const path of paths) {
                DBus.call("session", "org.kde.kglobalaccel", path, "org.kde.kglobalaccel.Component", "allShortcutInfos", [], (ok2, infos) => {
                    if (ok2) {
                        for (const info of infos) {
                            if (!page.hidden.includes(info[2]) && String(info[1]).length > 0) {
                                found.push({ component: info[2], componentName: info[3], name: info[0],
                                             title: info[0] === "_launch" ? i18nc("start the app", "Open") : info[1],
                                             keys: info[6], defaults: info[7] });
                            }
                        }
                    }
                    pending -= 1;
                    if (pending === 0) {
                        const order = c => {
                            const index = page.groups.findIndex(g => g.id === c);
                            return index < 0 ? page.groups.length : index;
                        };
                        found.sort((a, b) => (order(a.component) - order(b.component))
                                   || page.groupTitle(a.component, a.componentName).localeCompare(page.groupTitle(b.component, b.componentName))
                                   || a.title.localeCompare(b.title));
                        page.actions = found;
                        page.loaded = true;
                    }
                });
            }
        });
    }
    Component.onCompleted: load()

    readonly property var shown: {
        const needle = search.text.trim().toLowerCase();
        if (needle.length === 0) {
            return actions;
        }
        return actions.filter(a => a.title.toLowerCase().includes(needle)
                                   || Locales.shortcutText(a.keys).toLowerCase().includes(needle)
                                   || groupTitle(a.component, a.componentName).toLowerCase().includes(needle));
    }

    readonly property var shownGroups: {
        const list = [];
        for (const action of shown) {
            const title = groupTitle(action.component, action.componentName);
            let group = list.find(g => g.title === title);
            if (!group) {
                group = { title: title, actions: [] };
                list.push(group);
            }
            group.actions.push(action);
        }
        return list;
    }

    function actionId(action: var): var {
        return { type: "as", value: [action.component, action.name, action.componentName, action.title] };
    }

    function apply(action: var, keys: var): void {
        DBus.call("session", "org.kde.kglobalaccel", "/kglobalaccel", "org.kde.KGlobalAccel", "setForeignShortcut",
                  [actionId(action), { type: "ai", value: keys }], ok => {
                      if (!ok) {
                          page.notify(i18n("The shortcut could not be changed."));
                      }
                  });
        actions = actions.map(a => a.component === action.component && a.name === action.name ? Object.assign({}, a, { keys: keys }) : a);
    }

    function take(keys: var, except: var): void {
        for (const other of actions) {
            if (!(other.component === except.component && other.name === except.name) && other.keys.some(k => keys.includes(k))) {
                apply(other, other.keys.filter(k => !keys.includes(k)));
            }
        }
    }

    SearchField {
        id: search
        width: parent.width
        placeholderText: i18n("Search shortcuts")
    }

    EmptyState {
        visible: page.loaded && page.shown.length === 0
        icon: "preferences-desktop-keyboard-shortcut"
        title: i18n("No shortcuts found")
        text: search.text.length > 0 ? i18n("Try another word.") : ""
    }

    Repeater {
        model: page.shownGroups
        delegate: Group {
            id: group
            required property var modelData
            title: modelData.title

            Repeater {
                model: group.modelData.actions
                delegate: ListItem {
                    required property var modelData
                    title: modelData.title
                    value: Locales.shortcutText(modelData.keys) || i18n("None")
                    onClicked: recorder.edit(modelData)
                }
            }
        }
    }

    Dialog {
        id: recorder

        property var action: ({})
        property int key: 0
        property var conflicts: []

        function edit(action: var): void {
            recorder.action = action;
            recorder.key = 0;
            recorder.conflicts = [];
            open();
        }

        function record(event: var): void {
            const modifiers = event.modifiers & (Qt.ShiftModifier | Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier | Qt.KeypadModifier);
            if ([Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_AltGr].includes(event.key)) {
                return;
            }
            if (event.key === Qt.Key_Escape && modifiers === 0) {
                recorder.rejected();
                return;
            }
            recorder.key = modifiers | event.key;
            DBus.call("session", "org.kde.kglobalaccel", "/kglobalaccel", "org.kde.KGlobalAccel", "getGlobalShortcutsByKey",
                      [{ type: "i", value: recorder.key }], (ok, found) => {
                          recorder.conflicts = ok ? found.filter(f => !(f[2] === recorder.action.component && f[0] === recorder.action.name)) : [];
                      });
        }

        icon: "preferences-desktop-keyboard-shortcut"
        title: action.name === "_launch" ? page.groupTitle(action.component, action.componentName) : (action.title || "")
        text: key !== 0 ? "" : i18n("Press the new shortcut, or Esc to cancel.")
        acceptText: i18n("Set")
        acceptEnabled: key !== 0
        closePolicy: QQC2.Popup.NoAutoClose
        preferredWidth: 460
        onOpened: {
            DBus.call("session", "org.kde.kglobalaccel", "/kglobalaccel", "org.kde.KGlobalAccel", "blockGlobalShortcuts", [{ type: "b", value: true }], null);
            catcher.forceActiveFocus();
        }
        onClosed: DBus.call("session", "org.kde.kglobalaccel", "/kglobalaccel", "org.kde.KGlobalAccel", "blockGlobalShortcuts", [{ type: "b", value: false }], null)
        onAccepted: {
            for (const f of recorder.conflicts) {
                page.apply({ component: f[2], name: f[0], componentName: f[3], title: f[1] }, f[6].filter(k => k !== recorder.key));
            }
            page.apply(recorder.action, [recorder.key]);
        }

        Item {
            id: catcher
            Layout.fillWidth: true
            implicitHeight: 72
            focus: true
            Keys.onPressed: event => {
                recorder.record(event);
                event.accepted = true;
            }

            Rectangle {
                anchors.fill: parent
                radius: 16
                color: M3.surfaceContainerHighest
                border.width: catcher.activeFocus ? 2 : 0
                border.color: M3.primary

                MText {
                    anchors.centerIn: parent
                    role: "titleLarge"
                    text: recorder.key !== 0 ? Locales.shortcutText([recorder.key])
                                             : (Locales.shortcutText(recorder.action.keys || []) || i18n("None"))
                    color: recorder.key !== 0 ? M3.primary : M3.surfaceVariantContent
                }
            }
        }

        MText {
            Layout.fillWidth: true
            visible: recorder.conflicts.length > 0
            role: "bodyMedium"
            color: M3.error
            wrapMode: Text.Wrap
            text: i18n("Already used for “%1”. It will be taken from there.", recorder.conflicts.length > 0 ? recorder.conflicts[0][1] : "")
        }

        ListItem {
            Layout.fillWidth: true
            title: i18n("Default")
            subtitle: Locales.shortcutText(recorder.action.defaults || []) || i18n("None")
            icon: "edit-undo"
            iconStyle: "plain"
            onClicked: {
                const defaults = recorder.action.defaults || [];
                page.take(defaults, recorder.action);
                page.apply(recorder.action, defaults);
                recorder.close();
            }
        }
        ListItem {
            Layout.fillWidth: true
            title: i18n("No shortcut")
            icon: "edit-clear"
            iconStyle: "plain"
            onClicked: {
                page.apply(recorder.action, []);
                recorder.close();
            }
        }
    }
}
