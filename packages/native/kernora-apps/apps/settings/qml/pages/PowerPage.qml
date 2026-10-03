/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.private.batterymonitor
import org.kde.plasma.private.battery
import org.kernora.m3
import org.kernora.ui
import org.kernora.system
import "../components"

SettingsPage {
    id: page

    title: i18n("Battery & power")

    BatteryControlModel {
        id: battery
    }
    PowerProfilesControl {
        id: profiles
        isSilent: true
    }

    readonly property bool hasBattery: battery.hasInternalBatteries
    property string profile: hasBattery && !battery.pluggedIn ? "Battery" : "AC"

    function refreshPowerDevil(): void {
        DBus.call("session", "org.kde.Solid.PowerManagement", "/org/kde/Solid/PowerManagement",
                  "org.kde.Solid.PowerManagement", "refreshStatus", [], null);
    }

    function minutes(seconds: int): string {
        if (seconds <= 0) {
            return i18n("Never");
        }
        if (seconds < 3600) {
            return i18np("After %1 minute", "After %1 minutes", Math.round(seconds / 60));
        }
        return i18np("After %1 hour", "After %1 hours", Math.round(seconds / 3600));
    }
    function timeoutOptions(values: var): var {
        return values.map(v => ({ value: v, label: page.minutes(v) }));
    }

    Rectangle {
        width: parent.width
        visible: page.hasBattery
        implicitHeight: 112
        radius: M3.classic ? M3.cornerCard : 28
        color: battery.pluggedIn ? M3.primaryContainer : M3.surfaceContainerHigh

        RowLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 20
            MIcon {
                size: 48
                source: battery.pluggedIn ? "battery-charging" : "battery-full"
                color: battery.pluggedIn ? M3.primaryContainerContent : M3.surfaceContent
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                MText {
                    role: "displaySmall"
                    text: i18n("%1%", battery.percent)
                    color: battery.pluggedIn ? M3.primaryContainerContent : M3.surfaceContent
                }
                MText {
                    role: "bodyMedium"
                    text: battery.pluggedIn
                        ? (battery.state === BatteryControlModel.FullyCharged ? i18n("Fully charged") : i18n("Charging"))
                        : i18n("On battery power")
                    color: battery.pluggedIn ? M3.primaryContainerContent : M3.surfaceVariantContent
                }
            }
        }
    }

    Group {
        title: i18n("Power mode")
        visible: profiles.isPowerProfileDaemonInstalled && profiles.profiles.length > 0

        SegmentedButtons {
            width: parent.width
            options: [
                { value: "power-saver", label: i18n("Power saver"), icon: "battery-profile-powersave" },
                { value: "balanced", label: i18n("Balanced"), icon: "preferences-system-power-management" },
                { value: "performance", label: i18n("Performance"), icon: "battery-profile-performance" }
            ].filter(o => profiles.profiles.includes(o.value))
            currentValue: profiles.activeProfile
            onSelected: value => profiles.setProfile(value)
        }
        MText {
            width: parent.width
            topPadding: 8
            leftPadding: 16
            rightPadding: 16
            role: "bodySmall"
            color: M3.surfaceVariantContent
            wrapMode: Text.Wrap
            text: profiles.activeProfile === "performance" ? i18n("Faster, but uses more power and may run warmer.")
                : profiles.activeProfile === "power-saver" ? i18n("Longer battery life; the computer may feel slower.")
                : i18n("A balance of speed and battery life.")
        }
    }

    SegmentedButtons {
        width: parent.width
        visible: page.hasBattery
        options: [
            { value: "AC", label: i18n("Plugged in"), icon: "battery-ac-adapter" },
            { value: "Battery", label: i18n("On battery"), icon: "battery-full" }
        ]
        currentValue: page.profile
        onSelected: value => page.profile = value
    }

    ConfigEntry { id: dimOn; file: "powerdevilrc"; group: page.profile + "/Display"; key: "DimDisplayWhenIdle"; defaultValue: true }
    ConfigEntry { id: dimAfter; file: "powerdevilrc"; group: page.profile + "/Display"; key: "DimDisplayIdleTimeoutSec"; defaultValue: page.profile === "AC" ? 300 : 120 }
    ConfigEntry { id: offOn; file: "powerdevilrc"; group: page.profile + "/Display"; key: "TurnOffDisplayWhenIdle"; defaultValue: true }
    ConfigEntry { id: offAfter; file: "powerdevilrc"; group: page.profile + "/Display"; key: "TurnOffDisplayIdleTimeoutSec"; defaultValue: page.profile === "AC" ? 600 : 300 }
    ConfigEntry { id: sleepAction; file: "powerdevilrc"; group: page.profile + "/SuspendAndShutdown"; key: "AutoSuspendAction"; defaultValue: 1 }
    ConfigEntry { id: sleepAfter; file: "powerdevilrc"; group: page.profile + "/SuspendAndShutdown"; key: "AutoSuspendIdleTimeoutSec"; defaultValue: page.profile === "AC" ? 900 : 600 }
    ConfigEntry { id: powerButton; file: "powerdevilrc"; group: page.profile + "/SuspendAndShutdown"; key: "PowerButtonAction"; defaultValue: 16 }
    ConfigEntry { id: lidAction; file: "powerdevilrc"; group: page.profile + "/SuspendAndShutdown"; key: "LidAction"; defaultValue: 1 }

    function isOn(entry: var): bool {
        return entry.value === true || entry.value === "true";
    }

    Group {
        title: i18n("Screen")

        ChoiceItem {
            title: i18n("Dim the screen")
            icon: "brightness-low"
            accent: 3
            options: page.timeoutOptions([0, 60, 120, 300, 600, 900, 1800])
            currentValue: page.isOn(dimOn) ? Number(dimAfter.value) : 0
            onSelected: value => {
                dimOn.value = value > 0;
                if (value > 0) {
                    dimAfter.value = value;
                }
                page.refreshPowerDevil();
            }
        }
        ChoiceItem {
            title: i18n("Turn off the screen")
            icon: "video-display"
            accent: 3
            options: page.timeoutOptions([0, 120, 300, 600, 900, 1800, 3600])
            currentValue: page.isOn(offOn) ? Number(offAfter.value) : 0
            onSelected: value => {
                offOn.value = value > 0;
                if (value > 0) {
                    offAfter.value = value;
                }
                page.refreshPowerDevil();
            }
        }
    }

    Group {
        title: i18n("Sleep")

        ChoiceItem {
            title: i18n("Sleep when inactive")
            icon: "system-suspend"
            accent: 3
            options: page.timeoutOptions([0, 300, 600, 900, 1800, 3600, 7200])
            currentValue: Number(sleepAction.value) === 0 ? 0 : Number(sleepAfter.value)
            onSelected: value => {
                sleepAction.value = value > 0 ? 1 : 0;
                if (value > 0) {
                    sleepAfter.value = value;
                }
                page.refreshPowerDevil();
            }
        }
        ChoiceItem {
            title: i18n("Power button")
            icon: "system-shutdown"
            iconStyle: "plain"
            options: [
                { value: 16, label: i18n("Ask what to do") },
                { value: 1, label: i18n("Sleep") },
                { value: 8, label: i18n("Shut down") },
                { value: 32, label: i18n("Lock the screen") },
                { value: 64, label: i18n("Turn off the screen") },
                { value: 0, label: i18n("Do nothing") }
            ]
            currentValue: Number(powerButton.value)
            onSelected: value => {
                powerButton.value = value;
                page.refreshPowerDevil();
            }
        }
        ChoiceItem {
            title: i18n("When the lid is closed")
            visible: page.hasBattery
            icon: "computer-laptop"
            iconStyle: "plain"
            options: [
                { value: 1, label: i18n("Sleep") },
                { value: 32, label: i18n("Lock the screen") },
                { value: 64, label: i18n("Turn off the screen") },
                { value: 8, label: i18n("Shut down") },
                { value: 0, label: i18n("Do nothing") }
            ]
            currentValue: Number(lidAction.value)
            onSelected: value => {
                lidAction.value = value;
                page.refreshPowerDevil();
            }
        }
    }

    Group {
        ListItem {
            title: i18n("Advanced power settings")
            subtitle: i18n("Low battery, charge limits, other devices")
            icon: "configure"
            iconStyle: "plain"
            chevron: true
            onClicked: Process.openModule("kcm_powerdevilprofilesconfig")
        }
    }
}
