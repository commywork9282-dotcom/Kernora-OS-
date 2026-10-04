/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import org.kernora.m3
import org.kernora.ui
import org.kernora.system
import "../components"

SettingsPage {
    id: page

    title: i18n("Touchpad and mouse options")

    property var devices: []
    property bool loaded: false

    function loadDevices(): void {
        DBus.getProperty("session", "org.kde.KWin", "/org/kde/KWin/InputDevice", "org.kde.KWin.InputDeviceManager", "devicesSysNames", (ok, names) => {
            if (!ok || names.length === 0) {
                page.loaded = true;
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
                        page.loaded = true;
                    }
                });
            }
        });
    }
    Component.onCompleted: loadDevices()

    function set(device: var, values: var): void {
        for (const name in values) {
            DBus.setProperty("session", "org.kde.KWin", "/org/kde/KWin/InputDevice/" + device.sysName, "org.kde.KWin.InputDevice", name, values[name], ok => {
                if (!ok) {
                    page.notify(i18n("The setting could not be changed."));
                }
            });
        }
        const updated = Object.assign({}, device, values);
        devices = devices.map(x => x.sysName === device.sysName ? updated : x);
    }

    function restoreDefaults(device: var): void {
        const tapping = device.tapFingerCount > 0;
        const flags = {
            leftHanded: !!device.supportsLeftHanded,
            disableWhileTyping: !!device.supportsDisableWhileTyping,
            tapToClick: tapping,
            tapAndDrag: tapping,
            tapDragLock: tapping,
            lmrTapButtonMap: !!device.supportsLmrTapButtonMap,
            middleEmulation: !!device.supportsMiddleEmulation,
            naturalScroll: !!device.supportsNaturalScroll,
            scrollTwoFinger: !!device.supportsScrollTwoFinger,
            scrollEdge: !!device.supportsScrollEdge,
            scrollOnButtonDown: !!device.supportsScrollOnButtonDown,
            disableEventsOnExternalMouse: !!device.supportsDisableEventsOnExternalMouse
        };
        const values = {};
        for (const flag in flags) {
            if (flags[flag] && device[flag + "EnabledByDefault"] !== undefined) {
                values[flag] = device[flag + "EnabledByDefault"];
            }
        }
        const defaults = {
            pointerAcceleration: ["defaultPointerAcceleration", device.supportsPointerAcceleration],
            pointerAccelerationProfileFlat: ["defaultPointerAccelerationProfileFlat", device.supportsPointerAccelerationProfileFlat],
            pointerAccelerationProfileAdaptive: ["defaultPointerAccelerationProfileAdaptive", device.supportsPointerAccelerationProfileAdaptive],
            clickMethodAreas: ["defaultClickMethodAreas", device.supportsClickMethodAreas],
            clickMethodClickfinger: ["defaultClickMethodClickfinger", device.supportsClickMethodClickfinger]
        };
        for (const name in defaults) {
            const [key, supported] = defaults[name];
            if (supported && device[key] !== undefined) {
                values[name] = device[key];
            }
        }
        values.scrollFactor = 1.0;
        set(device, values);
    }

    EmptyState {
        visible: page.loaded && page.devices.length === 0
        icon: "input-mouse"
        title: i18n("No mouse or touchpad")
        text: i18n("Connect a mouse or a touchpad to set it up.")
    }

    Repeater {
        model: page.devices

        delegate: Group {
            id: device
            required property var modelData
            readonly property var d: modelData
            readonly property bool touchpad: !!d.touchpad
            title: touchpad ? i18n("Touchpad") : (page.devices.filter(x => !x.touchpad).length > 1 ? d.name : i18n("Mouse"))
            note: touchpad || page.devices.filter(x => !x.touchpad).length > 1 ? d.name : ""

            ListItem {
                title: i18n("Use the touchpad")
                visible: device.touchpad && device.d.supportsDisableEvents !== false
                icon: "input-touchpad"
                iconStyle: "plain"
                checkable: true
                checked: device.d.enabled !== false
                onToggled: on => page.set(device.d, { enabled: on })
            }
            ListItem {
                title: i18n("Turn off while a mouse is connected")
                visible: device.touchpad && !!device.d.supportsDisableEventsOnExternalMouse
                icon: "input-mouse"
                iconStyle: "plain"
                checkable: true
                checked: !!device.d.disableEventsOnExternalMouse
                onToggled: on => page.set(device.d, { disableEventsOnExternalMouse: on })
            }
            ListItem {
                title: i18n("Pointer acceleration")
                subtitle: i18n("Faster movements take the pointer further")
                visible: !!device.d.supportsPointerAccelerationProfileAdaptive && !!device.d.supportsPointerAccelerationProfileFlat
                icon: "go-next"
                iconStyle: "plain"
                checkable: true
                checked: !!device.d.pointerAccelerationProfileAdaptive
                onToggled: on => page.set(device.d, { pointerAccelerationProfileAdaptive: on, pointerAccelerationProfileFlat: !on })
            }
            ChoiceItem {
                title: i18n("Scrolling")
                visible: device.touchpad && (!!device.d.supportsScrollTwoFinger || !!device.d.supportsScrollEdge)
                icon: "view-sort"
                iconStyle: "plain"
                options: [
                    { value: "two", label: i18n("With two fingers"), enabled: !!device.d.supportsScrollTwoFinger },
                    { value: "edge", label: i18n("Along the right edge"), enabled: !!device.d.supportsScrollEdge },
                    { value: "none", label: i18n("Off"), enabled: true }
                ].filter(o => o.enabled)
                currentValue: device.d.scrollTwoFinger ? "two" : (device.d.scrollEdge ? "edge" : "none")
                onSelected: value => page.set(device.d, { scrollTwoFinger: value === "two", scrollEdge: value === "edge" })
            }
            ListItem {
                title: i18n("Scroll while holding a button")
                subtitle: i18n("Hold the middle button and move the mouse")
                visible: !device.touchpad && !!device.d.supportsScrollOnButtonDown
                icon: "view-sort"
                iconStyle: "plain"
                checkable: true
                checked: !!device.d.scrollOnButtonDown
                onToggled: on => page.set(device.d, { scrollOnButtonDown: on })
            }
            ChoiceItem {
                title: i18n("Right click")
                visible: device.touchpad && !!device.d.supportsClickMethodAreas && !!device.d.supportsClickMethodClickfinger
                icon: "input-touchpad"
                iconStyle: "plain"
                options: [
                    { value: "areas", label: i18n("Press the bottom right corner") },
                    { value: "fingers", label: i18n("Press with two fingers") }
                ]
                currentValue: device.d.clickMethodClickfinger ? "fingers" : "areas"
                onSelected: value => page.set(device.d, { clickMethodAreas: value === "areas", clickMethodClickfinger: value === "fingers" })
            }
            ListItem {
                title: i18n("Tap and drag")
                subtitle: i18n("Tap, then touch again and move to drag")
                visible: device.touchpad && device.d.tapFingerCount > 0
                icon: "transform-move"
                iconStyle: "plain"
                checkable: true
                checked: !!device.d.tapAndDrag
                onToggled: on => page.set(device.d, { tapAndDrag: on })
            }
            ListItem {
                title: i18n("Drag lock")
                subtitle: i18n("Lifting the finger for a moment does not drop what you drag")
                visible: device.touchpad && device.d.tapFingerCount > 0 && !!device.d.tapAndDrag
                icon: "object-locked"
                iconStyle: "plain"
                checkable: true
                checked: !!device.d.tapDragLock
                onToggled: on => page.set(device.d, { tapDragLock: on })
            }
            ChoiceItem {
                title: i18n("Two-finger tap")
                visible: device.touchpad && device.d.tapFingerCount > 1 && !!device.d.supportsLmrTapButtonMap
                icon: "input-touchpad"
                iconStyle: "plain"
                options: [
                    { value: false, label: i18n("Right click"), description: i18n("Three fingers: middle click") },
                    { value: true, label: i18n("Middle click"), description: i18n("Three fingers: right click") }
                ]
                currentValue: !!device.d.lmrTapButtonMap
                onSelected: value => page.set(device.d, { lmrTapButtonMap: value })
            }
            ListItem {
                title: i18n("Middle click with both buttons")
                subtitle: i18n("Press the left and right buttons together")
                visible: !!device.d.supportsMiddleEmulation
                icon: "input-mouse"
                iconStyle: "plain"
                checkable: true
                checked: !!device.d.middleEmulation
                onToggled: on => page.set(device.d, { middleEmulation: on })
            }
            ListItem {
                title: i18n("Restore defaults")
                icon: "edit-undo"
                iconStyle: "plain"
                onClicked: page.restoreDefaults(device.d)
            }
        }
    }
}
