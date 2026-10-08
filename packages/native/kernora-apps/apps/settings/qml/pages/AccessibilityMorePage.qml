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

    title: i18n("More accessibility options")

    function isOn(entry: var): bool {
        return entry.value === true || entry.value === "true";
    }
    function restartKAccess(): void {
        Process.startDetached("kaccess", []);
    }
    function reconfigureKWin(): void {
        DBus.call("session", "org.kde.KWin", "/KWin", "org.kde.KWin", "reconfigure", [], null);
    }
    function milliseconds(values: var): var {
        return values.map(v => ({ value: v, label: i18n("%1 ms", v) }));
    }

    ConfigEntry { id: stickyKeys; file: "kaccessrc"; group: "Keyboard"; key: "StickyKeys"; defaultValue: false }
    ConfigEntry { id: stickyLatch; file: "kaccessrc"; group: "Keyboard"; key: "StickyKeysLatch"; defaultValue: true }
    ConfigEntry { id: stickyAutoOff; file: "kaccessrc"; group: "Keyboard"; key: "StickyKeysAutoOff"; defaultValue: false }
    ConfigEntry { id: stickyBeep; file: "kaccessrc"; group: "Keyboard"; key: "StickyKeysBeep"; defaultValue: true }
    ConfigEntry { id: slowKeys; file: "kaccessrc"; group: "Keyboard"; key: "SlowKeys"; defaultValue: false }
    ConfigEntry { id: slowDelay; file: "kaccessrc"; group: "Keyboard"; key: "SlowKeysDelay"; defaultValue: 500 }
    ConfigEntry { id: bounceKeys; file: "kaccessrc"; group: "Keyboard"; key: "BounceKeys"; defaultValue: false }
    ConfigEntry { id: bounceDelay; file: "kaccessrc"; group: "Keyboard"; key: "BounceKeysDelay"; defaultValue: 500 }
    ConfigEntry { id: gestures; file: "kaccessrc"; group: "Keyboard"; key: "Gestures"; defaultValue: false }
    ConfigEntry { id: toggleBeep; file: "kaccessrc"; group: "Keyboard"; key: "ToggleKeysBeep"; defaultValue: false }
    ConfigEntry { id: mouseKeys; file: "kaccessrc"; group: "Mouse"; key: "MouseKeys"; defaultValue: false }
    ConfigEntry { id: mouseSpeed; file: "kaccessrc"; group: "Mouse"; key: "MKMaxSpeed"; defaultValue: 1000 }
    ConfigEntry { id: systemBell; file: "kaccessrc"; group: "Bell"; key: "SystemBell"; defaultValue: true }
    ConfigEntry { id: shakeCursor; file: "kwinrc"; group: "Plugins"; key: "shakecursorEnabled"; defaultValue: true }

    Group {
        title: i18n("Sticky keys")
        visible: page.isOn(stickyKeys)

        ListItem {
            title: i18n("Lock a key pressed twice")
            subtitle: i18n("Press Shift twice and it stays on until you press it again")
            icon: "object-locked"
            iconStyle: "plain"
            checkable: true
            checked: page.isOn(stickyLatch)
            onToggled: on => { stickyLatch.value = on; page.restartKAccess(); }
        }
        ListItem {
            title: i18n("Turn off when two keys are pressed together")
            icon: "input-keyboard"
            iconStyle: "plain"
            checkable: true
            checked: page.isOn(stickyAutoOff)
            onToggled: on => { stickyAutoOff.value = on; page.restartKAccess(); }
        }
        ListItem {
            title: i18n("Sound when a modifier key is used")
            icon: "audio-volume-high"
            iconStyle: "plain"
            checkable: true
            checked: page.isOn(stickyBeep)
            onToggled: on => { stickyBeep.value = on; page.restartKAccess(); }
        }
    }

    Group {
        title: i18n("Key delays")
        visible: page.isOn(slowKeys) || page.isOn(bounceKeys)

        ChoiceItem {
            title: i18n("Hold a key for")
            visible: page.isOn(slowKeys)
            icon: "chronometer"
            iconStyle: "plain"
            options: page.milliseconds([150, 300, 500, 750, 1000])
            currentValue: Number(slowDelay.value)
            onSelected: value => { slowDelay.value = value; page.restartKAccess(); }
        }
        ChoiceItem {
            title: i18n("Ignore repeated presses for")
            visible: page.isOn(bounceKeys)
            icon: "chronometer"
            iconStyle: "plain"
            options: page.milliseconds([150, 300, 500, 750, 1000])
            currentValue: Number(bounceDelay.value)
            onSelected: value => { bounceDelay.value = value; page.restartKAccess(); }
        }
    }

    Group {
        title: i18n("Keyboard")

        ListItem {
            title: i18n("Turn features on with the keyboard")
            subtitle: i18n("Press Shift five times for sticky keys, or hold it for eight seconds for slow keys")
            icon: "input-keyboard"
            iconStyle: "plain"
            checkable: true
            checked: page.isOn(gestures)
            onToggled: on => { gestures.value = on; page.restartKAccess(); }
        }
        ListItem {
            title: i18n("Sound for Caps Lock and Num Lock")
            icon: "audio-volume-high"
            iconStyle: "plain"
            checkable: true
            checked: page.isOn(toggleBeep)
            onToggled: on => { toggleBeep.value = on; page.restartKAccess(); }
        }
    }

    Group {
        title: i18n("Pointer")

        ListItem {
            title: i18n("Move the pointer with the number keys")
            subtitle: i18n("The keys around 5 move it, 5 clicks")
            icon: "input-mouse"
            iconStyle: "plain"
            checkable: true
            checked: page.isOn(mouseKeys)
            onToggled: on => { mouseKeys.value = on; page.restartKAccess(); }
        }
        ChoiceItem {
            title: i18n("Pointer speed with the keys")
            visible: page.isOn(mouseKeys)
            icon: "go-next"
            iconStyle: "plain"
            options: [
                { value: 400, label: i18n("Slow") },
                { value: 1000, label: i18n("Default") },
                { value: 2000, label: i18n("Fast") }
            ]
            currentValue: Number(mouseSpeed.value)
            onSelected: value => { mouseSpeed.value = value; page.restartKAccess(); }
        }
        ListItem {
            title: i18n("Shake the pointer to find it")
            subtitle: i18n("Shaking the mouse makes the pointer bigger for a moment")
            icon: "preferences-desktop-cursors"
            iconStyle: "plain"
            checkable: true
            checked: page.isOn(shakeCursor)
            onToggled: on => { shakeCursor.value = on; page.reconfigureKWin(); }
        }
    }

    Group {
        title: i18n("Alerts")

        ListItem {
            title: i18n("Play the system bell")
            subtitle: i18n("A short sound when an app asks for attention")
            icon: "preferences-desktop-notification-bell"
            iconStyle: "plain"
            checkable: true
            checked: page.isOn(systemBell)
            onToggled: on => { systemBell.value = on; page.restartKAccess(); }
        }
    }
}
