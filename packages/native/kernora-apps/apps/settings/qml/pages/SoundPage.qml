/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.private.volume
import org.kernora.m3
import org.kernora.ui
import org.kernora.system
import "../components"

SettingsPage {
    id: page

    title: i18n("Sound")

    readonly property var sink: PreferredDevice.sink
    readonly property var source: PreferredDevice.source
    readonly property bool hasOutput: !!sink && sink.name !== "auto_null"
    readonly property bool hasInput: !!source && source.name !== "auto_null"

    SinkModel { id: sinks }
    SourceModel { id: sources }
    SinkInputModel { id: streams }

    PulseObjectFilterModel {
        id: outputs
        filterOutInactiveDevices: true
        filterVirtualDevices: true
        sourceModel: sinks
    }
    PulseObjectFilterModel {
        id: inputs
        filterOutInactiveDevices: true
        filterVirtualDevices: true
        sourceModel: sources
    }
    PulseObjectFilterModel {
        id: appStreams
        filters: [ { role: "VirtualStream", value: false } ]
        sourceModel: streams
    }

    Instantiator {
        id: outputList
        model: outputs
        delegate: QtObject {
            required property var model
            readonly property var pulseObject: model.PulseObject
            readonly property string description: model.Description || ""
        }
    }
    Instantiator {
        id: inputList
        model: inputs
        delegate: QtObject {
            required property var model
            readonly property var pulseObject: model.PulseObject
            readonly property string description: model.Description || ""
        }
    }

    function devices(list: Instantiator): var {
        const result = [];
        for (let i = 0; i < list.count; ++i) {
            const item = list.objectAt(i);
            if (item && item.pulseObject) {
                result.push({ value: item.pulseObject.index, label: item.description || item.pulseObject.name, object: item.pulseObject });
            }
        }
        return result;
    }

    function percent(volume: real): int {
        return Math.round(100 * volume / PulseAudio.NormalVolume);
    }

    function setVolume(device: var, value: real): void {
        if (!device) {
            return;
        }
        device.volume = Math.round(value);
        device.muted = value <= PulseAudio.MinimalVolume;
    }

    EmptyState {
        visible: !page.hasOutput && !page.hasInput
        icon: "audio-volume-muted"
        title: i18n("No sound devices")
        text: i18n("Connect speakers or headphones to hear sound.")
    }

    Group {
        title: i18n("Output")
        visible: page.hasOutput

        SliderItem {
            title: i18n("Volume")
            icon: page.sink && page.sink.muted ? "audio-volume-muted" : "audio-volume-high"
            accent: 1
            startIcon: "audio-volume-low"
            endIcon: "audio-volume-high"
            from: PulseAudio.MinimalVolume
            to: PulseAudio.NormalVolume
            value: page.sink ? (page.sink.muted ? 0 : page.sink.volume) : 0
            formatValue: v => page.sink && page.sink.muted ? i18n("Muted") : i18n("%1%", page.percent(v))
            onMoved: value => page.setVolume(page.sink, value)
        }
        ChoiceItem {
            title: i18n("Play sound through")
            icon: "audio-speakers"
            iconStyle: "plain"
            options: page.devices(outputList)
            currentValue: page.sink ? page.sink.index : -1
            onSelected: value => {
                const device = options.find(o => o.value === value);
                if (device) {
                    device.object.default = true;
                }
            }
        }
        ListItem {
            title: i18n("Mute")
            icon: "audio-volume-muted"
            iconStyle: "plain"
            checkable: true
            checked: page.sink ? page.sink.muted : false
            onToggled: on => page.sink.muted = on
        }
    }

    Group {
        title: i18n("Input")
        visible: page.hasInput

        SliderItem {
            title: i18n("Microphone volume")
            icon: page.source && page.source.muted ? "microphone-sensitivity-muted" : "audio-input-microphone"
            accent: 4
            startIcon: "microphone-sensitivity-muted"
            endIcon: "audio-input-microphone"
            from: PulseAudio.MinimalVolume
            to: PulseAudio.NormalVolume
            value: page.source ? (page.source.muted ? 0 : page.source.volume) : 0
            formatValue: v => page.source && page.source.muted ? i18n("Muted") : i18n("%1%", page.percent(v))
            onMoved: value => page.setVolume(page.source, value)
        }
        ChoiceItem {
            title: i18n("Record sound from")
            icon: "audio-input-microphone"
            iconStyle: "plain"
            options: page.devices(inputList)
            currentValue: page.source ? page.source.index : -1
            onSelected: value => {
                const device = options.find(o => o.value === value);
                if (device) {
                    device.object.default = true;
                }
            }
        }
        ListItem {
            title: i18n("Mute microphone")
            icon: "microphone-sensitivity-muted"
            iconStyle: "plain"
            checkable: true
            checked: page.source ? page.source.muted : false
            onToggled: on => page.source.muted = on
        }
    }

    Group {
        title: i18n("Apps")
        visible: appStreams.count > 0
        note: i18n("Apps appear here while they play sound.")

        Repeater {
            model: appStreams
            delegate: SliderItem {
                required property var model
                title: model.Client && model.Client.name ? model.Client.name : model.Name
                icon: model.IconName || "audio-x-generic"
                startIcon: "audio-volume-low"
                endIcon: "audio-volume-high"
                from: PulseAudio.MinimalVolume
                to: PulseAudio.NormalVolume
                value: model.Muted ? 0 : model.Volume
                formatValue: v => model.Muted ? i18n("Muted") : i18n("%1%", page.percent(v))
                onMoved: value => {
                    model.Volume = Math.round(value);
                    model.Muted = value <= PulseAudio.MinimalVolume;
                }
            }
        }
    }

    ConfigEntry {
        id: feedback
        file: "plasmaparc"
        group: "General"
        key: "AudioFeedback"
        defaultValue: true
    }

    ConfigEntry {
        id: loginSound
        file: "plasma_workspace.notifyrc"
        group: "Event\\/startkde"
        key: "Action"
        defaultValue: ""
    }

    Group {
        title: i18n("System sounds")

        ListItem {
            title: i18n("Sounds")
            subtitle: i18n("Kernora")
            icon: "preferences-desktop-sound"
            iconStyle: "plain"
            trailing: Component {
                IconButton {
                    iconName: "media-playback-start"
                    text: i18n("Listen")
                    onClicked: Process.startDetached("pw-play", ["/usr/share/sounds/kernora/stereo/theme-demo.wav"])
                }
            }
        }
        ListItem {
            title: i18n("Sound at login")
            subtitle: i18n("A short chime when the desktop is ready")
            icon: "user-identity"
            iconStyle: "plain"
            checkable: true
            checked: String(loginSound.value).split("|").includes("Sound")
            onToggled: on => {
                const actions = String(loginSound.value).split("|").filter(a => a.length > 0 && a !== "Sound");
                if (on) {
                    actions.push("Sound");
                }
                loginSound.value = actions.join("|");
            }
        }
        ListItem {
            title: i18n("Volume change sound")
            subtitle: i18n("Play a short sound when the volume changes")
            icon: "preferences-desktop-sound"
            iconStyle: "plain"
            checkable: true
            checked: feedback.value === true || feedback.value === "true"
            onToggled: on => feedback.value = on
        }
        ListItem {
            title: i18n("Advanced sound settings")
            subtitle: i18n("Profiles, channel balance, every device")
            icon: "configure"
            iconStyle: "plain"
            chevron: true
            onClicked: page.open("SoundDevicesPage.qml", {})
        }
    }
}
