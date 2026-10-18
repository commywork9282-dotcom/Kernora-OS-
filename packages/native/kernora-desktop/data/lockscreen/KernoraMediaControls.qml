/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.plasma.private.mpris as Mpris
import org.kernora.m3

Rectangle {
    id: pill

    Mpris.Mpris2Model {
        id: players
    }

    readonly property var player: players.currentPlayer
    readonly property int playbackStatus: player?.playbackStatus ?? Mpris.PlaybackStatus.Unknown
    readonly property bool playing: playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property string track: player?.track ?? ""
    readonly property string artist: player?.artist ?? ""
    readonly property bool active: !!player && (track.length > 0 || playbackStatus > Mpris.PlaybackStatus.Stopped)
    readonly property bool canControl: player?.canControl ?? false

    implicitWidth: 420
    implicitHeight: 72
    radius: M3.classic ? M3.cornerCard : 36
    color: Qt.alpha(M3.surfaceContainerHigh, 0.94)

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 12

        Item {
            Layout.preferredWidth: 48
            Layout.preferredHeight: 48

            Rectangle {
                anchors.fill: parent
                radius: 24
                color: M3.secondaryContainer
                visible: art.status !== Image.Ready
                MIcon {
                    anchors.centerIn: parent
                    size: 24
                    source: "audio-x-generic"
                    color: M3.secondaryContainerContent
                }
            }
            Image {
                id: art
                anchors.fill: parent
                source: pill.player?.artUrl ?? ""
                sourceSize.width: 96
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
            }
            MultiEffect {
                anchors.fill: parent
                source: art
                visible: art.status === Image.Ready
                maskEnabled: true
                maskSource: artMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }
            Rectangle {
                id: artMask
                anchors.fill: parent
                radius: 24
                visible: false
                layer.enabled: true
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
                Layout.fillWidth: true
                text: pill.track || (pill.player?.identity ?? "")
                color: M3.surfaceContent
                font.family: M3.typeface
                font.pixelSize: 16
                font.weight: Font.Medium
                elide: Text.ElideRight
                renderType: Text.QtRendering
            }
            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: pill.artist
                color: M3.surfaceVariantContent
                font.family: M3.typeface
                font.pixelSize: 14
                elide: Text.ElideRight
                renderType: Text.QtRendering
            }
        }

        MediaButton {
            icon: "media-skip-backward"
            enabled: pill.canControl && (pill.player?.canGoPrevious ?? false)
            onClicked: pill.player.Previous()
        }

        Rectangle {
            id: play
            implicitWidth: 48
            implicitHeight: 48
            radius: 24 - 10 * playMorph.value
            color: M3.primary
            opacity: pill.canControl ? 1 : 0.38
            MMorph {
                id: playMorph
                active: pill.playing && !M3.classic
                dampingRatio: M3.springExpressiveDefaultDamping
                response: M3.springExpressiveDefaultResponse
            }
            MIcon {
                anchors.centerIn: parent
                size: 24
                source: pill.playing ? "media-playback-pause" : "media-playback-start"
                color: M3.primaryContent
            }
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: M3.primaryContent
                opacity: playMouse.pressed ? 0.12 : (playMouse.containsMouse ? 0.08 : 0)
            }
            MouseArea {
                id: playMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: pill.canControl
                cursorShape: Qt.PointingHandCursor
                onClicked: pill.playing ? pill.player.Pause() : pill.player.Play()
            }
        }

        MediaButton {
            icon: "media-skip-forward"
            enabled: pill.canControl && (pill.player?.canGoNext ?? false)
            onClicked: pill.player.Next()
        }
    }

    component MediaButton: Item {
        id: button
        property string icon
        signal clicked()
        implicitWidth: 40
        implicitHeight: 40
        opacity: enabled ? 1 : 0.38
        Rectangle {
            anchors.fill: parent
            radius: 20
            color: M3.surfaceContent
            opacity: buttonMouse.pressed ? 0.12 : (buttonMouse.containsMouse ? 0.08 : 0)
        }
        MIcon {
            anchors.centerIn: parent
            size: 24
            source: button.icon
            color: M3.surfaceContent
        }
        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }
}
