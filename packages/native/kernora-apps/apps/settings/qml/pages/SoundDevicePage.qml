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

    property var device
    property var card
    property bool output: true

    title: device ? (device.description || device.name) : ""
    subtitle: device && device.default ? i18n("In use") : ""

    readonly property real maximumVolume: raise.value === true || raise.value === "true" ? PulseAudio.MaximalVolume : PulseAudio.NormalVolume
    readonly property var channels: device ? (device.channels || []) : []

    ConfigEntry {
        id: raise
        file: "plasmaparc"
        group: "General"
        key: "RaiseMaximumVolume"
        defaultValue: false
    }

    SpeakerTest {
        id: speakerTest
        sink: page.output ? page.device : null
    }

    readonly property var rawChannels: device ? (device.rawChannels || []) : []
    readonly property bool stereo: rawChannels.length === 2 && rawChannels[0] === "front-left" && rawChannels[1] === "front-right"

    function channelName(index: int): string {
        const raw = rawChannels[index] || "";
        if (stereo) {
            return index === 0 ? i18n("Left") : i18n("Right");
        }
        const names = {
            "mono": i18n("Mono"),
            "front-left": i18n("Front left"),
            "front-right": i18n("Front right"),
            "front-center": i18n("Front centre"),
            "rear-left": i18n("Rear left"),
            "rear-right": i18n("Rear right"),
            "rear-center": i18n("Rear centre"),
            "side-left": i18n("Side left"),
            "side-right": i18n("Side right"),
            "lfe": i18n("Subwoofer")
        };
        return names[raw] || channels[index] || raw;
    }

    function percent(volume: real): string {
        return i18n("%1%", Math.round(100 * volume / PulseAudio.NormalVolume));
    }

    Group {
        title: page.output ? i18n("Output") : i18n("Input")

        ListItem {
            title: page.output ? i18n("Play sound through this device") : i18n("Record sound from this device")
            icon: page.output ? "audio-speakers" : "audio-input-microphone"
            iconStyle: "plain"
            checkable: true
            checked: page.device ? page.device.default : false
            interactive: page.device ? !page.device.default : false
            onToggled: on => {
                if (on) {
                    page.device.default = true;
                }
            }
        }
        SliderItem {
            title: i18n("Volume")
            icon: page.device && page.device.muted ? (page.output ? "audio-volume-muted" : "audio-input-microphone-muted")
                                                    : (page.output ? "audio-volume-high" : "audio-input-microphone")
            accent: page.output ? 1 : 4
            startIcon: "audio-volume-low"
            endIcon: "audio-volume-high"
            from: PulseAudio.MinimalVolume
            to: page.maximumVolume
            value: page.device ? (page.device.muted ? 0 : page.device.volume) : 0
            formatValue: v => page.device && page.device.muted ? i18n("Muted") : page.percent(v)
            onMoved: value => {
                page.device.volume = Math.round(value);
                page.device.muted = value <= PulseAudio.MinimalVolume;
            }
        }
        ListItem {
            title: i18n("Mute")
            icon: page.output ? "audio-volume-muted" : "audio-input-microphone-muted"
            iconStyle: "plain"
            checkable: true
            checked: page.device ? page.device.muted : false
            onToggled: on => page.device.muted = on
        }
        ChoiceItem {
            title: i18n("Connector")
            visible: page.device && (page.device.ports || []).length > 1
            icon: page.output ? "audio-headphones" : "audio-headset"
            iconStyle: "plain"
            options: page.device ? (page.device.ports || []).map((port, index) => ({
                value: index,
                label: port.description || port.name,
                description: port.availability === Port.Unavailable ? i18n("Nothing plugged in") : ""
            })) : []
            currentValue: page.device ? page.device.activePortIndex : -1
            onSelected: value => page.device.activePortIndex = value
        }
        ChoiceItem {
            title: i18n("Profile")
            visible: !!page.card && (page.card.profiles || []).length > 1
            icon: "audio-card"
            iconStyle: "plain"
            options: page.card ? (page.card.profiles || []).map((profile, index) => ({
                value: index,
                label: profile.description || profile.name,
                description: profile.availability === Profile.Unavailable ? i18n("Not available") : ""
            })) : []
            currentValue: page.card ? page.card.activeProfileIndex : -1
            onSelected: value => page.card.activeProfileIndex = value
        }
    }

    Group {
        title: i18n("Channels")
        visible: page.channels.length > 1
        note: page.output ? i18n("Turn one side down to move the sound towards the other.") : ""

        Repeater {
            model: page.channels
            delegate: SliderItem {
                required property string modelData
                required property int index
                title: page.channelName(index)
                startIcon: "audio-volume-low"
                endIcon: "audio-volume-high"
                from: PulseAudio.MinimalVolume
                to: page.maximumVolume
                value: page.device && page.device.channelVolumes ? (page.device.channelVolumes[index] || 0) : 0
                formatValue: v => page.percent(v)
                onMoved: value => page.device.setChannelVolume(index, Math.round(value))
            }
        }
    }

    Group {
        title: i18n("Test speakers")
        visible: page.output && page.channels.length > 0
        note: i18n("Click a speaker to play a short sound from it.")

        Repeater {
            model: page.output ? page.rawChannels : []
            delegate: ListItem {
                required property string modelData
                required property int index
                title: page.channelName(index)
                icon: "media-playback-start"
                iconStyle: "plain"
                value: speakerTest.playingChannels.includes(modelData) ? i18n("Playing") : ""
                onClicked: speakerTest.testChannel(modelData)
            }
        }
    }
}
