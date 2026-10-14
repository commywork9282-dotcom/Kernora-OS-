/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kernora.ui as UI
import "m3"

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    switchWidth: Plasmoid.configuration.placed ? 0 : 379
    switchHeight: Plasmoid.configuration.placed ? 0 : 155

    Timer {
        running: !Plasmoid.configuration.placed
        interval: 2000
        onTriggered: Plasmoid.configuration.placed = true
    }

    toolTipMainText: media.active ? media.track : i18n("Now Playing")
    toolTipSubText: media.active ? media.artist : ""

    MediaSource {
        id: media
    }

    property real elapsed: media.position
    Connections {
        target: media
        function onPositionChanged() {
            root.elapsed = media.position;
        }
    }
    Timer {
        interval: 250
        running: media.playing
        repeat: true
        onTriggered: root.elapsed = Math.min(media.length, root.elapsed + 250000 * media.rate)
    }
    Timer {
        interval: 5000
        running: media.playing
        repeat: true
        onTriggered: media.updatePosition()
    }

    fullRepresentation: WidgetSurface {
        id: card
        Layout.preferredWidth: 380
        Layout.preferredHeight: 156
        Layout.minimumWidth: 260
        Layout.minimumHeight: 120
        color: media.active ? M3.secondaryContainer : M3.surfaceContainer
        clip: true

        RowLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16
            visible: media.active

            UI.RoundedClip {
                Layout.preferredWidth: card.height - 32
                Layout.preferredHeight: card.height - 32
                radius: M3.classic ? 4 : 20

                Rectangle {
                    anchors.fill: parent
                    color: M3.surfaceContainerHighest
                }
                MIcon {
                    anchors.centerIn: parent
                    size: Math.round(parent.width * 0.4)
                    source: "media-playback-start"
                    color: M3.surfaceVariantContent
                    visible: cover.status !== Image.Ready
                }
                Image {
                    id: cover
                    property int attempt: 0
                    anchors.fill: parent
                    source: media.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(256, 256)
                    onStatusChanged: {
                        if (status === Image.Error && attempt < 6) {
                            coverRetry.restart();
                        } else if (status === Image.Ready) {
                            attempt = 0;
                        }
                    }
                    Timer {
                        id: coverRetry
                        interval: 1500 * (cover.attempt + 1)
                        onTriggered: {
                            cover.attempt += 1;
                            cover.source = "";
                            cover.source = Qt.binding(() => media.artUrl);
                        }
                    }
                    Connections {
                        target: media
                        function onArtUrlChanged(): void {
                            cover.attempt = 0;
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 2

                MText {
                    Layout.fillWidth: true
                    role: "titleMedium"
                    color: M3.secondaryContainerContent
                    elide: Text.ElideRight
                    text: media.track || media.identity
                }
                MText {
                    Layout.fillWidth: true
                    role: "bodyMedium"
                    color: M3.secondaryContainerContent
                    opacity: 0.8
                    elide: Text.ElideRight
                    text: media.artist
                    visible: text.length > 0
                }
                Item {
                    Layout.fillHeight: true
                }
                WavyProgress {
                    Layout.fillWidth: true
                    visible: media.length > 0
                    color: M3.primary
                    playing: media.playing
                    interactive: media.canSeek
                    value: media.length > 0 ? root.elapsed / media.length : 0
                    onSeekRequested: value => {
                        root.elapsed = value * media.length;
                        media.seek(root.elapsed);
                    }
                }
                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 4

                    MIconButton {
                        icon: "media-skip-backward"
                        size: 36
                        iconSize: 20
                        enabled: media.canGoPrevious
                        onClicked: media.previous()
                    }
                    MIconButton {
                        icon: media.playing ? "media-playback-pause" : "media-playback-start"
                        variant: "filled"
                        size: 40
                        iconSize: 22
                        enabled: media.canPlayPause
                        onClicked: media.playPause()
                    }
                    MIconButton {
                        icon: "media-skip-forward"
                        size: 36
                        iconSize: 20
                        enabled: media.canGoNext
                        onClicked: media.next()
                    }
                }
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            visible: !media.active
            spacing: 8

            MIcon {
                Layout.alignment: Qt.AlignHCenter
                size: 32
                source: "media-playback-start"
                color: M3.primary
            }
            MText {
                Layout.alignment: Qt.AlignHCenter
                role: "titleSmall"
                text: i18n("Nothing is playing")
            }
        }
    }
}
