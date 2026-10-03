/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.plasma.private.volume

QtObject {
    id: root

    readonly property var sink: PreferredDevice.sink
    readonly property var source: PreferredDevice.source

    readonly property bool soundAvailable: !!sink && sink.name !== "auto_null"
    readonly property bool soundMuted: soundAvailable ? sink.muted : true
    readonly property real volume: soundAvailable ? sink.volume : 0
    readonly property real volumeMax: PulseAudio.NormalVolume
    readonly property int percent: Math.round(100 * volume / volumeMax)
    readonly property string outputName: soundAvailable ? (sink.description || i18n("On")) : i18n("Unavailable")
    readonly property string volumeIcon: AudioIcon.forVolume(percent, soundMuted, "")

    function setVolume(value: real): void {
        if (!soundAvailable) {
            return;
        }
        if (sink.muted && value > 0) {
            sink.muted = false;
        }
        sink.volume = Math.round(value);
    }

    function toggleMute(): void {
        if (soundAvailable) {
            sink.muted = !sink.muted;
        }
    }

    readonly property bool micAvailable: !!source && source.name !== "auto_null"
    readonly property bool micMuted: micAvailable ? source.muted : true

    function toggleMic(): void {
        if (micAvailable) {
            source.muted = !source.muted;
        }
    }
}
