/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.private.batterymonitor
import org.kde.plasma.private.battery
import org.kernora.m3
import org.kernora.ui
import org.kernora.system
import "../components"

SettingsPage {
    id: page

    title: i18n("Advanced power settings")

    BatteryControlModel {
        id: battery
    }
    PowerProfilesControl {
        id: profiles
        isSilent: true
    }

    readonly property bool hasBattery: battery.hasInternalBatteries
    property var sleepModes: [1]

    function refreshPowerDevil(): void {
        DBus.call("session", "org.kde.Solid.PowerManagement", "/org/kde/Solid/PowerManagement",
                  "org.kde.Solid.PowerManagement", "refreshStatus", [], null);
    }

    function percentOptions(values: var): var {
        return values.map(v => ({ value: v, label: i18n("%1%", v) }));
    }

    Component.onCompleted: {
        const checks = [["CanHybridSleep", 2], ["CanSuspendThenHibernate", 3]];
        for (const [method, mode] of checks) {
            DBus.call("system", "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", method, [], (ok, answer) => {
                if (ok && answer === "yes") {
                    page.sleepModes = page.sleepModes.concat([mode]).sort();
                }
            });
        }
        DBus.call("system", "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "CanHibernate", [], (ok, answer) => {
            page.canHibernate = ok && answer === "yes";
        });
    }
    property bool canHibernate: false

    ConfigEntry { id: lowLevel; file: "powerdevilrc"; group: "BatteryManagement"; key: "BatteryLowLevel"; defaultValue: 10 }
    ConfigEntry { id: criticalLevel; file: "powerdevilrc"; group: "BatteryManagement"; key: "BatteryCriticalLevel"; defaultValue: 5 }
    ConfigEntry { id: criticalAction; file: "powerdevilrc"; group: "BatteryManagement"; key: "BatteryCriticalAction"; defaultValue: page.canHibernate ? 2 : 8 }
    ConfigEntry { id: peripheralLevel; file: "powerdevilrc"; group: "BatteryManagement"; key: "PeripheralBatteryLowLevel"; defaultValue: 10 }
    ConfigEntry { id: pausePlayers; file: "powerdevilrc"; group: "General"; key: "PausePlayersOnSuspend"; defaultValue: true }
    ConfigEntry { id: sleepModeAC; file: "powerdevilrc"; group: "AC/SuspendAndShutdown"; key: "SleepMode"; defaultValue: 1 }
    ConfigEntry { id: sleepModeBattery; file: "powerdevilrc"; group: "Battery/SuspendAndShutdown"; key: "SleepMode"; defaultValue: 1 }
    ConfigEntry { id: sleepModeLow; file: "powerdevilrc"; group: "LowBattery/SuspendAndShutdown"; key: "SleepMode"; defaultValue: 1 }
    ConfigEntry { id: modeAC; file: "powerdevilrc"; group: "AC/Performance"; key: "PowerProfile"; defaultValue: "" }
    ConfigEntry { id: modeBattery; file: "powerdevilrc"; group: "Battery/Performance"; key: "PowerProfile"; defaultValue: "" }
    ConfigEntry { id: modeLow; file: "powerdevilrc"; group: "LowBattery/Performance"; key: "PowerProfile"; defaultValue: "power-saver" }

    Group {
        title: i18n("Battery")
        visible: page.hasBattery

        ChoiceItem {
            title: i18n("Warn about low battery at")
            icon: "battery-low"
            iconStyle: "plain"
            options: page.percentOptions([5, 10, 15, 20, 25, 30])
            currentValue: Number(lowLevel.value)
            onSelected: value => {
                lowLevel.value = value;
                page.refreshPowerDevil();
            }
        }
        ChoiceItem {
            title: i18n("Critical battery level")
            icon: "battery-caution"
            iconStyle: "plain"
            options: page.percentOptions([2, 3, 5, 7, 10])
            currentValue: Number(criticalLevel.value)
            onSelected: value => {
                criticalLevel.value = value;
                page.refreshPowerDevil();
            }
        }
        ChoiceItem {
            title: i18n("At the critical level")
            icon: "system-shutdown"
            iconStyle: "plain"
            options: [
                { value: 2, label: i18n("Hibernate"), description: i18n("Save everything to disk and turn off"), available: page.canHibernate },
                { value: 1, label: i18n("Sleep"), available: true },
                { value: 8, label: i18n("Shut down"), available: true },
                { value: 0, label: i18n("Do nothing"), available: true }
            ].filter(o => o.available)
            currentValue: Number(criticalAction.value)
            onSelected: value => {
                criticalAction.value = value;
                page.refreshPowerDevil();
            }
        }
    }

    Group {
        title: i18n("Other devices")
        note: i18n("Wireless mice, keyboards, headphones and other devices with their own battery.")

        ChoiceItem {
            title: i18n("Warn about their low battery at")
            icon: "input-mouse"
            iconStyle: "plain"
            options: page.percentOptions([5, 10, 15, 20, 25, 30])
            currentValue: Number(peripheralLevel.value)
            onSelected: value => {
                peripheralLevel.value = value;
                page.refreshPowerDevil();
            }
        }
    }

    Group {
        title: i18n("Power mode for each state")
        visible: profiles.isPowerProfileDaemonInstalled && profiles.profiles.length > 0
        note: i18n("The power mode switches by itself when the computer changes between these states.")

        Repeater {
            model: [
                { entry: modeAC, title: i18n("Plugged in"), icon: "battery-ac-adapter", shown: true },
                { entry: modeBattery, title: i18n("On battery"), icon: "battery-full", shown: page.hasBattery },
                { entry: modeLow, title: i18n("Low battery"), icon: "battery-low", shown: page.hasBattery }
            ]
            delegate: ChoiceItem {
                required property var modelData
                visible: modelData.shown
                title: modelData.title
                icon: modelData.icon
                iconStyle: "plain"
                options: [
                    { value: "", label: i18n("Leave as it is") },
                    { value: "power-saver", label: i18n("Power saver") },
                    { value: "balanced", label: i18n("Balanced") },
                    { value: "performance", label: i18n("Performance") }
                ].filter(o => o.value === "" || profiles.profiles.includes(o.value))
                currentValue: String(modelData.entry.value || "")
                onSelected: value => {
                    modelData.entry.value = value;
                    page.refreshPowerDevil();
                }
            }
        }
    }

    Group {
        title: i18n("Sleep")

        ChoiceItem {
            title: i18n("How to sleep")
            visible: page.sleepModes.length > 1
            icon: "system-suspend"
            iconStyle: "plain"
            options: [
                { value: 1, label: i18n("Sleep"), description: i18n("Keeps working in memory, wakes up at once") },
                { value: 2, label: i18n("Hybrid sleep"), description: i18n("Also saves to disk in case the power runs out") },
                { value: 3, label: i18n("Sleep, then hibernate"), description: i18n("Hibernates after some time asleep") }
            ].filter(o => page.sleepModes.includes(o.value))
            currentValue: Number(sleepModeAC.value)
            onSelected: value => {
                sleepModeAC.value = value;
                sleepModeBattery.value = value;
                sleepModeLow.value = value;
                page.refreshPowerDevil();
            }
        }
        ListItem {
            title: i18n("Pause media before sleep")
            subtitle: i18n("Music and videos stop when the computer goes to sleep")
            icon: "media-playback-pause"
            iconStyle: "plain"
            checkable: true
            checked: pausePlayers.value === true || pausePlayers.value === "true"
            onToggled: on => {
                pausePlayers.value = on;
                page.refreshPowerDevil();
            }
        }
    }
}
