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

    title: i18n("Keyboard, mouse & touchpad")

    property var layouts: Locales.currentLayouts()
    property var allLayouts: []

    function saveLayouts(list: var): void {
        Locales.setLayouts(list);
        layouts = Locales.currentLayouts();
    }

    Group {
        title: i18n("Keyboard layouts")
        note: page.layouts.length > 1 ? i18n("The first layout is used when you log in.") : ""

        Repeater {
            model: page.layouts
            delegate: ListItem {
                id: layoutRow
                required property var modelData
                required property int index
                title: modelData.name || modelData.layout
                subtitle: index === 0 && page.layouts.length > 1 ? i18n("Main layout") : ""
                leading: Component {
                    Rectangle {
                        implicitWidth: 40
                        implicitHeight: 40
                        radius: 20
                        color: layoutRow.index === 0 ? M3.accent(2).container : M3.surfaceContainerHighest
                        MText {
                            anchors.centerIn: parent
                            role: "labelLarge"
                            text: String(layoutRow.modelData.layout).toUpperCase().slice(0, 3)
                            color: layoutRow.index === 0 ? M3.accent(2).content : M3.surfaceVariantContent
                        }
                    }
                }
                trailing: Component {
                    RowLayout {
                        spacing: 0
                        IconButton {
                            visible: layoutRow.index > 0
                            iconName: "go-up"
                            text: i18n("Make main layout")
                            onClicked: {
                                const list = page.layouts.slice();
                                const [moved] = list.splice(layoutRow.index, 1);
                                list.unshift(moved);
                                page.saveLayouts(list);
                            }
                        }
                        IconButton {
                            visible: page.layouts.length > 1
                            iconName: "user-trash"
                            text: i18n("Remove")
                            onClicked: {
                                const list = page.layouts.slice();
                                list.splice(layoutRow.index, 1);
                                page.saveLayouts(list);
                            }
                        }
                    }
                }
                interactive: false
            }
        }
        ListItem {
            title: i18n("Add a layout")
            icon: "list-add"
            accent: 2
            chevron: true
            onClicked: {
                if (page.allLayouts.length === 0) {
                    page.allLayouts = Locales.keyboardLayouts();
                }
                addLayout.open();
            }
        }
        ChoiceItem {
            title: i18n("Switch layouts with")
            visible: page.layouts.length > 1
            icon: "input-keyboard"
            iconStyle: "plain"
            options: [
                { value: "", label: i18n("Meta+Alt+K"), description: i18n("The desktop shortcut") },
                { value: "grp:alt_shift_toggle", label: i18n("Alt+Shift") },
                { value: "grp:ctrl_shift_toggle", label: i18n("Ctrl+Shift") },
                { value: "grp:caps_toggle", label: i18n("Caps Lock") },
                { value: "grp:win_space_toggle", label: i18n("Super+Space (XKB)") }
            ]
            currentValue: Locales.layoutSwitchOption()
            onSelected: value => Locales.setLayoutSwitchOption(value)
        }
    }

    ChoiceDialog {
        id: addLayout
        title: i18n("Add a layout")
        searchable: true
        options: page.allLayouts
            .filter(l => !page.layouts.some(c => c.layout === l.layout && (c.variant || "") === (l.variant || "")))
            .map(l => ({ value: l.layout + "|" + (l.variant || ""), label: l.name, description: l.variant ? "" : l.layout.toUpperCase() }))
        onChosen: value => {
            const parts = String(value).split("|");
            const list = page.layouts.slice();
            list.push({ layout: parts[0], variant: parts[1] || "" });
            page.saveLayouts(list);
        }
    }

    ConfigEntry { id: repeatDelay; file: "kcminputrc"; group: "Keyboard"; key: "RepeatDelay"; defaultValue: 600 }
    ConfigEntry { id: repeatRate; file: "kcminputrc"; group: "Keyboard"; key: "RepeatRate"; defaultValue: 25 }
    ConfigEntry { id: keyRepeat; file: "kcminputrc"; group: "Keyboard"; key: "KeyRepeat"; defaultValue: "repeat" }
    ConfigEntry { id: numLock; file: "kcminputrc"; group: "Keyboard"; key: "NumLock"; defaultValue: 2 }

    Group {
        title: i18n("Typing")

        ListItem {
            title: i18n("Repeat keys")
            subtitle: i18n("Holding a key down types it again and again")
            icon: "input-keyboard"
            iconStyle: "plain"
            checkable: true
            checked: keyRepeat.value !== "nothing"
            onToggled: on => keyRepeat.value = on ? "repeat" : "nothing"
        }
        SliderItem {
            title: i18n("Delay before repeating")
            visible: keyRepeat.value !== "nothing"
            from: 200
            to: 1000
            stepSize: 50
            value: Number(repeatDelay.value)
            formatValue: v => i18n("%1 ms", Math.round(v))
            onMoved: value => repeatDelay.value = Math.round(value)
        }
        SliderItem {
            title: i18n("Repeat speed")
            visible: keyRepeat.value !== "nothing"
            from: 5
            to: 60
            stepSize: 1
            value: Number(repeatRate.value)
            formatValue: v => i18n("%1 per second", Math.round(v))
            onMoved: value => repeatRate.value = Math.round(value)
        }
        ChoiceItem {
            title: i18n("Num Lock at login")
            icon: "input-keyboard"
            iconStyle: "plain"
            options: [
                { value: 0, label: i18n("On") },
                { value: 1, label: i18n("Off") },
                { value: 2, label: i18n("Leave as it is") }
            ]
            currentValue: Number(numLock.value)
            onSelected: value => numLock.value = value
        }
    }

    property var devices: []

    function loadDevices(): void {
        DBus.getProperty("session", "org.kde.KWin", "/org/kde/KWin/InputDevice", "org.kde.KWin.InputDeviceManager", "devicesSysNames", (ok, names) => {
            if (!ok) {
                return;
            }
            const found = [];
            let pending = names.length;
            for (const name of names) {
                DBus.getAllProperties("session", "org.kde.KWin", "/org/kde/KWin/InputDevice/" + name, "org.kde.KWin.InputDevice", (ok2, props) => {
                    if (ok2 && props.pointer && !props.tabletTool && !props.touch) {
                        props.sysName = name;
                        found.push(props);
                    }
                    pending -= 1;
                    if (pending === 0) {
                        page.devices = found.filter(d => !String(d.name).includes("Virtual") || d.touchpad)
                            .sort((a, b) => (b.touchpad - a.touchpad) || String(a.name).localeCompare(String(b.name)));
                    }
                });
            }
        });
    }
    Component.onCompleted: loadDevices()

    function setDeviceProperty(device: var, name: string, value: var): void {
        DBus.setProperty("session", "org.kde.KWin", "/org/kde/KWin/InputDevice/" + device.sysName, "org.kde.KWin.InputDevice", name, value, ok => {
            if (!ok) {
                page.notify(i18n("The setting could not be changed."));
            }
        });
        const updated = Object.assign({}, device);
        updated[name] = value;
        devices = devices.map(x => x.sysName === device.sysName ? updated : x);
    }

    Repeater {
        model: page.devices

        delegate: Group {
            id: device
            required property var modelData
            title: modelData.touchpad ? i18n("Touchpad") : (page.devices.filter(d => !d.touchpad).length > 1 ? modelData.name : i18n("Mouse"))

            SliderItem {
                id: speedSlider
                title: i18n("Pointer speed")
                visible: device.modelData.supportsPointerAcceleration !== false
                icon: device.modelData.touchpad ? "input-touchpad" : "input-mouse"
                accent: 2
                startIcon: "go-previous"
                endIcon: "go-next"
                from: -1
                to: 1
                stepSize: 0.05
                value: Number(device.modelData.pointerAcceleration || 0)
                formatValue: v => Math.abs(v) < 0.03 ? i18n("Default") : (v > 0 ? "+" : "−") + Math.round(Math.abs(v) * 100) + "%"
                onMoved: value => speedApply.restart()
                Timer {
                    id: speedApply
                    interval: 120
                    onTriggered: page.setDeviceProperty(device.modelData, "pointerAcceleration", speedSlider.value)
                }
            }
            ListItem {
                title: i18n("Natural scrolling")
                subtitle: i18n("Content moves the way your fingers move")
                visible: device.modelData.supportsNaturalScroll !== false
                icon: "view-sort"
                iconStyle: "plain"
                checkable: true
                checked: !!device.modelData.naturalScroll
                onToggled: on => page.setDeviceProperty(device.modelData, "naturalScroll", on)
            }
            ListItem {
                title: i18n("Tap to click")
                visible: device.modelData.touchpad && device.modelData.tapFingerCount > 0
                icon: "input-touchpad"
                iconStyle: "plain"
                checkable: true
                checked: !!device.modelData.tapToClick
                onToggled: on => page.setDeviceProperty(device.modelData, "tapToClick", on)
            }
            ListItem {
                title: i18n("Ignore while typing")
                visible: device.modelData.touchpad && device.modelData.supportsDisableWhileTyping !== false
                icon: "input-keyboard"
                iconStyle: "plain"
                checkable: true
                checked: !!device.modelData.disableWhileTyping
                onToggled: on => page.setDeviceProperty(device.modelData, "disableWhileTyping", on)
            }
            ListItem {
                title: i18n("Right button is the primary one")
                subtitle: i18n("For the left hand")
                visible: !device.modelData.touchpad && device.modelData.supportsLeftHanded !== false
                icon: "input-mouse"
                iconStyle: "plain"
                checkable: true
                checked: !!device.modelData.leftHanded
                onToggled: on => page.setDeviceProperty(device.modelData, "leftHanded", on)
            }
            ChoiceItem {
                title: i18n("Scrolling speed")
                icon: "view-sort"
                iconStyle: "plain"
                options: [0.5, 1, 1.5, 2, 3].map(v => ({ value: v, label: v === 1 ? i18n("Default") : i18n("%1×", v) }))
                currentValue: Number(device.modelData.scrollFactor || 1)
                onSelected: value => page.setDeviceProperty(device.modelData, "scrollFactor", value)
            }
        }
    }

    Group {
        title: i18n("More")

        ListItem {
            title: i18n("Keyboard shortcuts")
            icon: "preferences-desktop-keyboard-shortcut"
            iconStyle: "plain"
            chevron: true
            onClicked: page.open("ShortcutsPage.qml", {})
        }
        ListItem {
            title: i18n("Touchpad and mouse options")
            subtitle: i18n("Scrolling, tapping, right click, acceleration")
            icon: "input-touchpad"
            iconStyle: "plain"
            chevron: true
            onClicked: page.open("PointerOptionsPage.qml", {})
        }
        ListItem {
            title: i18n("Advanced keyboard options")
            subtitle: i18n("Compose key, special keys, keyboard model")
            icon: "configure"
            iconStyle: "plain"
            chevron: true
            onClicked: page.open("KeyboardOptionsPage.qml", {})
        }
    }
}
