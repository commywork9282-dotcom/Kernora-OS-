/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.private.brightnesscontrolplugin

Item {
    id: root

    ScreenBrightnessControl {
        id: brightnessControl
        isSilent: true
    }

    NightLightControl {
        id: nightLight
    }

    Instantiator {
        id: displays
        model: brightnessControl.displays
        delegate: QtObject {
            required property string displayName
            required property int brightness
            required property int maxBrightness
        }
    }

    readonly property var display: displays.count > 0 ? displays.objectAt(0) : null

    readonly property bool brightnessAvailable: brightnessControl.isBrightnessAvailable && display !== null
    readonly property real brightness: display ? display.brightness : 0
    readonly property real brightnessMax: display ? Math.max(1, display.maxBrightness) : 100

    function setBrightness(value: real): void {
        if (display) {
            brightnessControl.setBrightness(display.displayName, Math.round(value));
        }
    }

    readonly property bool nightAvailable: nightLight.available
    readonly property bool nightOn: nightLight.enabled && !nightLight.inhibited
    readonly property string nightSubtitle: {
        if (!nightAvailable) {
            return i18n("Unavailable");
        }
        if (!nightLight.enabled) {
            return i18n("Set up…");
        }
        return nightOn ? i18n("On") : i18n("Paused");
    }
    readonly property bool nightNeedsSetup: nightAvailable && !nightLight.enabled

    function toggleNight(): void {
        nightLight.toggleInhibition();
    }
}
