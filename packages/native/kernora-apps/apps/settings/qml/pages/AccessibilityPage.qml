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

    title: i18n("Accessibility")

    function reconfigureKWin(): void {
        DBus.call("session", "org.kde.KWin", "/KWin", "org.kde.KWin", "reconfigure", [], null);
    }
    function isOn(entry: var): bool {
        return entry.value === true || entry.value === "true";
    }

    ConfigEntry { id: zoom; file: "kwinrc"; group: "Plugins"; key: "zoomEnabled"; defaultValue: false }
    ConfigEntry { id: filterOn; file: "kwinrc"; group: "Plugins"; key: "colorblindnesscorrectionEnabled"; defaultValue: false }
    ConfigEntry { id: filterMode; file: "kwinrc"; group: "Effect-colorblindnesscorrection"; key: "Mode"; defaultValue: 0 }
    ConfigEntry { id: cursorSize; file: "kcminputrc"; group: "Mouse"; key: "cursorSize"; defaultValue: 24 }
    ConfigEntry { id: fontEntry; file: "kdeglobals"; group: "General"; key: "font"; defaultValue: "Roboto,10.5,-1,5,400,0,0,0,0,0,0,0,0,0,0,1" }

    readonly property real fontSize: {
        const size = parseFloat(String(fontEntry.value).split(",")[1]);
        return isNaN(size) ? 10.5 : size;
    }
    function fontString(size: real, weight: int): string {
        return "Roboto," + size + ",-1,5," + weight + ",0,0,0,0,0,0,0,0,0,0,1";
    }
    function setFontSize(size: real): void {
        const small = size - 1.5;
        Config.write("kdeglobals", "General", "font", fontString(size, 400), true);
        Config.write("kdeglobals", "General", "menuFont", fontString(size, 400), true);
        Config.write("kdeglobals", "General", "toolBarFont", fontString(small, 400), true);
        Config.write("kdeglobals", "General", "smallestReadableFont", fontString(small, 400), true);
        Config.write("kdeglobals", "WM", "activeFont", fontString(size, 500), true);
        DBus.emitSignal("session", "/KGlobalSettings", "org.kde.KGlobalSettings", "notifyChange",
                        [{ type: "i", value: 1 }, { type: "i", value: 0 }]);
        reconfigureKWin();
    }

    Group {
        title: i18n("Seeing")

        ListItem {
            title: i18n("Zoom")
            subtitle: i18n("Magnify the screen with Meta and + or −; Meta and 0 goes back")
            icon: "zoom-in"
            accent: 5
            checkable: true
            checked: page.isOn(zoom)
            onToggled: on => {
                zoom.value = on;
                page.reconfigureKWin();
            }
        }
        ChoiceItem {
            title: i18n("Text size")
            icon: "preferences-desktop-font"
            accent: 5
            options: [
                { value: 9.5, label: i18n("Small") },
                { value: 10.5, label: i18n("Default") },
                { value: 12, label: i18n("Large") },
                { value: 13.5, label: i18n("Larger") },
                { value: 15, label: i18n("Largest") }
            ]
            currentValue: page.fontSize
            onSelected: value => page.setFontSize(value)
        }
        ChoiceItem {
            title: i18n("Cursor size")
            icon: "preferences-desktop-cursors"
            accent: 5
            options: [
                { value: 24, label: i18n("Default") },
                { value: 32, label: i18n("Large") },
                { value: 48, label: i18n("Larger") },
                { value: 64, label: i18n("Largest") }
            ]
            currentValue: Number(cursorSize.value)
            onSelected: value => {
                cursorSize.value = value;
                DBus.emitSignal("session", "/KGlobalSettings", "org.kde.KGlobalSettings", "notifyChange",
                                [{ type: "i", value: 5 }, { type: "i", value: 0 }]);
                page.reconfigureKWin();
            }
        }
        ChoiceItem {
            title: i18n("Colour filter")
            icon: "preferences-desktop-display-color"
            accent: 5
            options: [
                { value: -1, label: i18n("Off") },
                { value: 0, label: i18n("Red-green (protanopia)") },
                { value: 1, label: i18n("Green-red (deuteranopia)") },
                { value: 2, label: i18n("Blue-yellow (tritanopia)") },
                { value: 3, label: i18n("Greyscale") }
            ]
            currentValue: page.isOn(filterOn) ? Number(filterMode.value) : -1
            onSelected: value => {
                filterOn.value = value >= 0;
                if (value >= 0) {
                    filterMode.value = value;
                }
                page.reconfigureKWin();
            }
        }
    }

    ConfigEntry { id: animationFactor; file: "kdeglobals"; group: "KDE"; key: "AnimationDurationFactor"; defaultValue: 1 }
    ConfigEntry { id: visibleBell; file: "kaccessrc"; group: "Bell"; key: "VisibleBell"; defaultValue: false }
    ConfigEntry { id: screenReader; file: "kaccessrc"; group: "ScreenReader"; key: "Enabled"; defaultValue: false }
    readonly property bool hasOrca: Process.findExecutable("orca").length > 0

    function restartKAccess(): void {
        Process.startDetached("kaccess", []);
    }

    Group {
        title: i18n("Motion and sound")

        ListItem {
            title: i18n("Reduce motion")
            subtitle: i18n("Turn off animations everywhere")
            icon: "preferences-desktop-effects"
            accent: 1
            checkable: true
            checked: Number(animationFactor.value) === 0
            onToggled: on => {
                animationFactor.value = on ? 0 : 1;
                page.reconfigureKWin();
            }
        }
        ListItem {
            title: i18n("Flash the screen for alerts")
            subtitle: i18n("Show the system bell instead of only playing it")
            icon: "notification-active"
            accent: 1
            checkable: true
            checked: page.isOn(visibleBell)
            onToggled: on => {
                visibleBell.value = on;
                page.restartKAccess();
            }
        }
        ListItem {
            title: i18n("Screen reader")
            subtitle: i18n("Orca reads out what is on the screen")
            visible: page.hasOrca
            icon: "preferences-desktop-accessibility"
            accent: 1
            checkable: true
            checked: page.isOn(screenReader)
            onToggled: on => {
                screenReader.value = on;
                if (on) {
                    Process.startDetached("orca", ["--replace"]);
                } else {
                    Process.run("pkill", ["-x", "orca"], null);
                }
            }
        }
    }

    ConfigEntry { id: stickyKeys; file: "kaccessrc"; group: "Keyboard"; key: "StickyKeys"; defaultValue: false }
    ConfigEntry { id: slowKeys; file: "kaccessrc"; group: "Keyboard"; key: "SlowKeys"; defaultValue: false }
    ConfigEntry { id: bounceKeys; file: "kaccessrc"; group: "Keyboard"; key: "BounceKeys"; defaultValue: false }

    Group {
        title: i18n("Keyboard")

        ListItem {
            title: i18n("Sticky keys")
            subtitle: i18n("Press Shift, Ctrl or Alt one after another instead of together")
            icon: "input-keyboard"
            accent: 2
            checkable: true
            checked: page.isOn(stickyKeys)
            onToggled: on => {
                stickyKeys.value = on;
                page.restartKAccess();
            }
        }
        ListItem {
            title: i18n("Slow keys")
            subtitle: i18n("A key counts only when held down for a moment")
            icon: "input-keyboard"
            accent: 2
            checkable: true
            checked: page.isOn(slowKeys)
            onToggled: on => {
                slowKeys.value = on;
                page.restartKAccess();
            }
        }
        ListItem {
            title: i18n("Bounce keys")
            subtitle: i18n("Ignore a key pressed again too quickly")
            icon: "input-keyboard"
            accent: 2
            checkable: true
            checked: page.isOn(bounceKeys)
            onToggled: on => {
                bounceKeys.value = on;
                page.restartKAccess();
            }
        }
    }

    Group {
        ListItem {
            title: i18n("More accessibility options")
            icon: "configure"
            iconStyle: "plain"
            chevron: true
            onClicked: Process.openModule("kcm_access")
        }
    }
}
