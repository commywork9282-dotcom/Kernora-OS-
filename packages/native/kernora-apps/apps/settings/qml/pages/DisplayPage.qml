/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.private.brightnesscontrolplugin
import org.kernora.m3
import org.kernora.ui
import org.kernora.system
import "../components"

SettingsPage {
    id: page

    title: i18n("Display & brightness")

    ScreenBrightnessControl {
        id: brightness
        isSilent: true
    }
    Instantiator {
        id: brightnessDisplays
        model: brightness.displays
        delegate: QtObject {
            required property string displayName
            required property string label
            required property int brightness
            required property int maxBrightness
        }
    }

    Group {
        title: i18n("Brightness")
        visible: brightness.isBrightnessAvailable && brightnessDisplays.count > 0

        Repeater {
            model: brightnessDisplays.count
            delegate: SliderItem {
                id: brightnessRow
                required property int index
                readonly property var display: brightnessDisplays.objectAt(index)
                title: brightnessDisplays.count > 1 && display ? display.label : i18n("Screen brightness")
                icon: "video-display-brightness"
                accent: 3
                startIcon: "brightness-low"
                endIcon: "brightness-high"
                from: 0
                to: display ? Math.max(1, display.maxBrightness) : 100
                value: display ? display.brightness : 0
                onMoved: value => brightness.setBrightness(display.displayName, Math.round(value))
            }
        }
    }

    NightLightControl {
        id: nightControl
    }

    ConfigEntry {
        id: nightActive
        file: "kwinrc"
        group: "NightColor"
        key: "Active"
        defaultValue: false
    }
    ConfigEntry {
        id: nightMode
        file: "kwinrc"
        group: "NightColor"
        key: "Mode"
        defaultValue: "Automatic"
    }
    ConfigEntry {
        id: nightTemperature
        file: "kwinrc"
        group: "NightColor"
        key: "NightTemperature"
        defaultValue: 4500
    }
    ConfigEntry {
        id: eveningBegins
        file: "kwinrc"
        group: "NightColor"
        key: "EveningBeginFixed"
        defaultValue: "1900"
    }
    ConfigEntry {
        id: morningBegins
        file: "kwinrc"
        group: "NightColor"
        key: "MorningBeginFixed"
        defaultValue: "0700"
    }

    function reconfigureKWin(): void {
        DBus.call("session", "org.kde.KWin", "/KWin", "org.kde.KWin", "reconfigure", [], null);
    }

    function clockText(hhmm: string): string {
        const text = String(hhmm).padStart(4, "0");
        const date = new Date(2000, 0, 1, parseInt(text.slice(0, 2)), parseInt(text.slice(2, 4)));
        return date.toLocaleTimeString(Qt.locale(), Locale.ShortFormat);
    }

    Group {
        title: i18n("Night Light")
        visible: nightControl.available
        note: i18n("Night Light makes the screen warmer, which is easier on the eyes in the evening.")

        ListItem {
            title: i18n("Use Night Light")
            subtitle: nightActive.value === true || nightActive.value === "true"
                ? (nightControl.inhibited ? i18n("Paused for now") : nightControl.running ? i18n("On now") : i18n("Waiting for the evening"))
                : i18n("Off")
            icon: "night-light"
            accent: 3
            checkable: true
            checked: nightActive.value === true || nightActive.value === "true"
            onToggled: on => {
                nightActive.value = on;
                page.reconfigureKWin();
            }
        }
        ChoiceItem {
            title: i18n("Schedule")
            icon: "clock"
            iconStyle: "plain"
            enabled: nightActive.value === true || nightActive.value === "true"
            options: [
                { value: "Constant", label: i18n("Always on") },
                { value: "Times", label: i18n("Custom times"), description: i18n("From %1 to %2", page.clockText(eveningBegins.value), page.clockText(morningBegins.value)) },
                { value: "Automatic", label: i18n("Sunset to sunrise"), description: i18n("Follows your location") }
            ]
            currentValue: nightMode.value
            onSelected: value => {
                nightMode.value = value;
                page.reconfigureKWin();
            }
        }
        ChoiceItem {
            title: i18n("Turns on at")
            icon: "clock"
            iconStyle: "plain"
            visible: nightMode.value === "Times"
            enabled: nightActive.value === true || nightActive.value === "true"
            options: page.hourOptions
            currentValue: String(eveningBegins.value).padStart(4, "0")
            onSelected: value => {
                eveningBegins.value = value;
                page.reconfigureKWin();
            }
        }
        ChoiceItem {
            title: i18n("Turns off at")
            icon: "clock"
            iconStyle: "plain"
            visible: nightMode.value === "Times"
            enabled: nightActive.value === true || nightActive.value === "true"
            options: page.hourOptions
            currentValue: String(morningBegins.value).padStart(4, "0")
            onSelected: value => {
                morningBegins.value = value;
                page.reconfigureKWin();
            }
        }
        SliderItem {
            title: i18n("Warmth")
            enabled: nightActive.value === true || nightActive.value === "true"
            startIcon: "light-mode"
            endIcon: "night-light"
            from: 6500
            to: 2500
            stepSize: 100
            value: Number(nightTemperature.value)
            formatValue: v => i18n("%1 K", Math.round(v))
            onMoved: value => {
                nightTemperature.value = Math.round(value);
                warmthApply.restart();
            }
            Timer {
                id: warmthApply
                interval: 250
                onTriggered: page.reconfigureKWin()
            }
        }
    }

    readonly property var hourOptions: {
        const result = [];
        for (let h = 0; h < 24; ++h) {
            for (const m of [0, 30]) {
                const value = String(h).padStart(2, "0") + String(m).padStart(2, "0");
                result.push({ value: value, label: clockText(value) });
            }
        }
        return result;
    }

    Displays {
        id: displays
        onApplied: ok => {
            if (!ok) {
                page.notify(i18n("The display settings could not be applied."));
                displays.revert();
            } else if (page.pendingConfirmation) {
                page.pendingConfirmation = false;
                keepDialog.open();
            }
        }
    }

    property bool pendingConfirmation: false

    function change(apply: var): void {
        displays.snapshot();
        pendingConfirmation = true;
        apply();
    }

    function scaleOptions(): var {
        return [1, 1.25, 1.5, 1.75, 2, 2.5, 3].map(s => ({ value: s, label: i18n("%1%", Math.round(s * 100)) }));
    }

    Repeater {
        model: displays

        delegate: Group {
            id: screen

            required property int index
            required property var model
            readonly property string label: model.label
            readonly property bool outputEnabled: model.enabled
            readonly property bool primary: model.primary
            readonly property var resolutions: model.resolutions
            readonly property string resolution: model.resolution
            readonly property string preferredResolution: model.preferredResolution
            readonly property var refreshRates: model.refreshRates
            readonly property real refresh: model.refresh
            readonly property real outputScale: model.scale
            readonly property int outputRotation: model.rotation

            title: displays.count > 1 ? label : i18n("Screen")

            ListItem {
                title: i18n("Use this screen")
                visible: displays.count > 1
                icon: "video-display"
                iconStyle: "plain"
                checkable: true
                checked: screen.outputEnabled
                onToggled: on => page.change(() => displays.setEnabled(screen.index, on))
            }
            ListItem {
                title: i18n("Main screen")
                subtitle: i18n("Holds the panel and new windows")
                visible: displays.count > 1 && screen.outputEnabled
                icon: "computer"
                iconStyle: "plain"
                checkable: true
                checked: screen.primary
                enabled: !screen.primary
                onToggled: on => {
                    if (on) {
                        displays.setPrimary(screen.index);
                    }
                }
            }
            ChoiceItem {
                title: i18n("Resolution")
                visible: screen.outputEnabled
                icon: "preferences-desktop-display"
                accent: 1
                options: screen.resolutions.map(r => ({
                    value: r,
                    label: r,
                    description: r === screen.preferredResolution ? i18n("Recommended") : ""
                }))
                currentValue: screen.resolution
                onSelected: value => page.change(() => displays.setResolution(screen.index, value))
            }
            ChoiceItem {
                title: i18n("Refresh rate")
                visible: screen.outputEnabled && screen.refreshRates.length > 1
                icon: "view-refresh"
                iconStyle: "plain"
                options: screen.refreshRates.map(r => ({ value: r, label: i18n("%1 Hz", Math.round(r * 100) / 100) }))
                currentValue: screen.refresh
                onSelected: value => page.change(() => displays.setRefresh(screen.index, value))
            }
            ChoiceItem {
                title: i18n("Scale")
                visible: screen.outputEnabled
                icon: "zoom-in"
                iconStyle: "plain"
                options: page.scaleOptions()
                currentValue: Math.round(screen.outputScale * 4) / 4
                onSelected: value => displays.setScale(screen.index, value)
            }
            ChoiceItem {
                title: i18n("Orientation")
                visible: screen.outputEnabled
                icon: "rotation-allowed"
                iconStyle: "plain"
                options: [
                    { value: 0, label: i18n("Landscape") },
                    { value: 90, label: i18n("Portrait") },
                    { value: 180, label: i18n("Landscape, flipped") },
                    { value: 270, label: i18n("Portrait, flipped") }
                ]
                currentValue: screen.outputRotation
                onSelected: value => page.change(() => displays.setRotation(screen.index, value))
            }
        }
    }

    Group {
        ListItem {
            title: i18n("Arrange screens and more")
            subtitle: i18n("Position of several screens, overscan, colour profiles")
            icon: "preferences-desktop-display-randr"
            iconStyle: "plain"
            chevron: true
            onClicked: Process.openModule("kcm_kscreen")
        }
    }

    Dialog {
        id: keepDialog

        property int remaining: 15

        icon: "preferences-desktop-display"
        title: i18n("Keep these display settings?")
        text: i18np("The previous settings come back in %1 second.", "The previous settings come back in %1 seconds.", remaining)
        acceptText: i18n("Keep")
        rejectText: i18n("Revert")
        closePolicy: QQC2.Popup.NoAutoClose

        onOpened: {
            remaining = 15;
            countdown.start();
        }
        onAccepted: countdown.stop()
        onRejected: {
            countdown.stop();
            displays.revert();
        }

        Timer {
            id: countdown
            interval: 1000
            repeat: true
            onTriggered: {
                keepDialog.remaining -= 1;
                if (keepDialog.remaining <= 0) {
                    stop();
                    keepDialog.close();
                    keepDialog.rejected();
                }
            }
        }
    }
}
