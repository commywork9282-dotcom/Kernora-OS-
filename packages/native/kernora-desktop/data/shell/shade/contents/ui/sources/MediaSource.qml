/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.plasma.private.mpris as Mpris

Item {
    id: media

    Mpris.Mpris2Model {
        id: players
    }

    readonly property var player: players.currentPlayer
    readonly property int playbackStatus: player?.playbackStatus ?? Mpris.PlaybackStatus.Unknown
    readonly property bool playing: playbackStatus === Mpris.PlaybackStatus.Playing

    readonly property string track: player?.track ?? ""
    readonly property string artist: player?.artist ?? ""
    readonly property string album: player?.album ?? ""
    readonly property string artUrl: player?.artUrl ?? ""
    readonly property string identity: player?.identity ?? ""
    readonly property string iconName: player?.iconName ?? ""
    readonly property bool active: !!player && (track.length > 0 || playbackStatus > Mpris.PlaybackStatus.Stopped)

    readonly property bool canControl: player?.canControl ?? false
    readonly property bool canPlayPause: canControl && ((player?.canPlay ?? false) || (player?.canPause ?? false))
    readonly property bool canGoNext: canControl && (player?.canGoNext ?? false)
    readonly property bool canGoPrevious: canControl && (player?.canGoPrevious ?? false)
    readonly property bool canSeek: canControl && (player?.canSeek ?? false)
    readonly property bool canRaise: player?.canRaise ?? false

    readonly property real length: player?.length ?? 0
    readonly property real position: player?.position ?? 0
    readonly property real rate: player?.rate ?? 1

    function playPause(): void {
        if (!player) {
            return;
        }
        if (playing) {
            player.Pause();
        } else {
            player.Play();
        }
    }
    function next(): void { player?.Next(); }
    function previous(): void { player?.Previous(); }
    function raise(): void { player?.Raise(); }
    function seek(microseconds: real): void {
        if (player && canSeek) {
            player.position = Math.max(0, Math.min(length, microseconds));
        }
    }
    function updatePosition(): void { player?.updatePosition(); }
}
