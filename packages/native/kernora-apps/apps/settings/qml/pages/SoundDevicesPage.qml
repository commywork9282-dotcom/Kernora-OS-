/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.private.volume
import org.kernora.m3
import org.kernora.ui
import org.kernora.system
import "../components"

SettingsPage {
    id: page

    title: i18n("Sound devices")

    readonly property real maximumVolume: raise.value === true || raise.value === "true" ? PulseAudio.MaximalVolume : PulseAudio.NormalVolume

    SinkModel { id: sinks }
    SourceModel { id: sources }
    CardModel { id: cards }
    StreamRestoreModel { id: restores }

    PulseObjectFilterModel {
        id: outputs
        filterVirtualDevices: true
        sourceModel: sinks
    }
    PulseObjectFilterModel {
        id: inputs
        filterVirtualDevices: true
        sourceModel: sources
    }

    Instantiator {
        id: cardList
        model: cards
        delegate: QtObject {
            required property var model
            readonly property var pulseObject: model.PulseObject
        }
    }

    Instantiator {
        id: restoreList
        model: restores
        delegate: QtObject {
            required property var model
            readonly property var pulseObject: model.PulseObject
        }
    }

    readonly property var notificationSounds: {
        for (let i = 0; i < restoreList.count; ++i) {
            const item = restoreList.objectAt(i);
            if (item && item.pulseObject && item.pulseObject.name === "sink-input-by-media-role:event") {
                return item.pulseObject;
            }
        }
        return null;
    }

    ConfigEntry {
        id: raise
        file: "plasmaparc"
        group: "General"
        key: "RaiseMaximumVolume"
        defaultValue: false
    }

    ConfigEntry {
        id: step
        file: "plasmaparc"
        group: "General"
        key: "VolumeStep"
        defaultValue: 5
    }

    function cardFor(device: var): var {
        for (let i = 0; i < cardList.count; ++i) {
            const item = cardList.objectAt(i);
            if (item && item.pulseObject && item.pulseObject.index === device.cardIndex) {
                return item.pulseObject;
            }
        }
        return null;
    }

    function cardName(card: var): string {
        const properties = card.properties || {};
        return properties["device.description"] || properties["alsa.card_name"] || card.name;
    }

    function deviceSummary(device: var): string {
        const parts = [];
        if (device.default) {
            parts.push(i18n("In use"));
        }
        const port = device.ports && device.ports[device.activePortIndex];
        if (port && port.description) {
            parts.push(port.description);
        }
        return parts.join(" · ");
    }

    EmptyState {
        visible: outputs.count === 0 && inputs.count === 0 && cards.count === 0
        icon: "audio-volume-muted"
        title: i18n("No sound devices")
        text: i18n("Connect speakers or headphones to hear sound.")
    }

    Group {
        title: i18n("Outputs")
        visible: outputs.count > 0

        Repeater {
            model: outputs
            delegate: ListItem {
                required property var model
                readonly property var device: model.PulseObject
                title: model.Description || device.name
                subtitle: page.deviceSummary(device)
                icon: device.default ? "audio-volume-high" : "audio-speakers"
                accent: device.default ? 1 : -1
                chevron: true
                onClicked: page.open("SoundDevicePage.qml", { device: device, card: page.cardFor(device), output: true })
            }
        }
    }

    Group {
        title: i18n("Inputs")
        visible: inputs.count > 0

        Repeater {
            model: inputs
            delegate: ListItem {
                required property var model
                readonly property var device: model.PulseObject
                title: model.Description || device.name
                subtitle: page.deviceSummary(device)
                icon: "audio-input-microphone"
                accent: device.default ? 4 : -1
                chevron: true
                onClicked: page.open("SoundDevicePage.qml", { device: device, card: page.cardFor(device), output: false })
            }
        }
    }

    Group {
        title: i18n("Sound cards")
        visible: cards.count > 0
        note: i18n("A profile decides which outputs and inputs a card offers, for example stereo, surround or HDMI.")

        Repeater {
            model: cards
            delegate: ChoiceItem {
                required property var model
                readonly property var card: model.PulseObject
                title: page.cardName(card)
                icon: "audio-card"
                iconStyle: "plain"
                dialogTitle: i18n("Profile")
                options: (card.profiles || []).map((profile, index) => ({
                    value: index,
                    label: profile.description || profile.name,
                    description: profile.availability === Profile.Unavailable ? i18n("Not available") : ""
                }))
                currentValue: card.activeProfileIndex
                onSelected: value => card.activeProfileIndex = value
            }
        }
    }

    Group {
        title: i18n("Volume")

        SliderItem {
            title: i18n("Notification sounds")
            visible: page.notificationSounds !== null
            icon: "preferences-desktop-notification-bell"
            startIcon: "audio-volume-low"
            endIcon: "audio-volume-high"
            from: PulseAudio.MinimalVolume
            to: PulseAudio.NormalVolume
            value: page.notificationSounds ? (page.notificationSounds.muted ? 0 : page.notificationSounds.volume) : 0
            formatValue: v => page.notificationSounds && page.notificationSounds.muted ? i18n("Muted") : i18n("%1%", Math.round(100 * v / PulseAudio.NormalVolume))
            onMoved: value => {
                page.notificationSounds.volume = Math.round(value);
                page.notificationSounds.muted = value <= PulseAudio.MinimalVolume;
            }
        }
        ListItem {
            title: i18n("Allow volume above 100%")
            subtitle: i18n("Up to 150%, which can distort the sound")
            icon: "audio-volume-high-warning"
            iconStyle: "plain"
            checkable: true
            checked: page.maximumVolume > PulseAudio.NormalVolume
            onToggled: on => raise.value = on
        }
        ChoiceItem {
            title: i18n("Volume step")
            icon: "audio-volume-medium"
            iconStyle: "plain"
            options: [1, 2, 5, 10].map(n => ({ value: n, label: i18n("%1%", n) }))
            currentValue: Number(step.value)
            onSelected: value => step.value = value
        }
    }
}
