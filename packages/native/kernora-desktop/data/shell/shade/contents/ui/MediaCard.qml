/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "m3"

Item {
    id: card

    required property QtObject backend

    signal requestClose()

    readonly property bool hasArt: art.status === Image.Ready
    readonly property color ink: hasArt ? "#ffffff" : M3.surfaceContent
    readonly property color softInk: hasArt ? "#d9ffffff" : M3.surfaceVariantContent

    implicitHeight: 164

    property real elapsed: backend.mediaPosition
    Connections {
        target: card.backend
        function onMediaPositionChanged() { card.elapsed = card.backend.mediaPosition; }
        function onMediaTrackChanged() { card.backend.mediaUpdatePosition(); }
    }
    Timer {
        interval: 250
        repeat: true
        running: card.visible && card.backend.mediaPlaying && card.backend.mediaLength > 0
        onTriggered: card.elapsed = Math.min(card.backend.mediaLength, card.elapsed + 250000 * card.backend.mediaRate)
    }
    onVisibleChanged: if (visible) backend.mediaUpdatePosition()

    function time(microseconds: real): string {
        const total = Math.max(0, Math.round(microseconds / 1000000));
        const hours = Math.floor(total / 3600);
        const minutes = Math.floor(total / 60) % 60;
        const seconds = (total % 60).toString().padStart(2, "0");
        return hours > 0 ? `${hours}:${minutes.toString().padStart(2, "0")}:${seconds}` : `${minutes}:${seconds}`;
    }

    Item {
        id: surface
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: mask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }

        Rectangle {
            anchors.fill: parent
            color: M3.surfaceContainerHighest
        }
        Image {
            id: art
            anchors.fill: parent
            source: card.backend.mediaArtUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 480
            visible: status === Image.Ready
        }
        Rectangle {
            anchors.fill: parent
            visible: card.hasArt
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.72) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.38) }
            }
        }

        MStateLayer {
            anchors.fill: parent
            color: card.ink
            hovered: raiseArea.containsMouse
            pressed: raiseArea.pressed
            pressPoint: Qt.point(raiseArea.mouseX, raiseArea.mouseY)
        }
        MouseArea {
            id: raiseArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: card.backend.mediaCanRaise
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                card.backend.mediaRaise();
                card.requestClose();
            }
        }
    }
    Rectangle {
        id: mask
        anchors.fill: parent
        radius: M3.cornerCard
        visible: false
        layer.enabled: true
    }

    component MediaButton: Item {
        id: mediaButton
        property string icon
        property string text
        signal clicked()
        implicitWidth: 40
        implicitHeight: 40
        opacity: enabled ? 1 : 0.38
        Accessible.role: Accessible.Button
        Accessible.name: text
        Accessible.onPressAction: clicked()
        MStateLayer {
            anchors.fill: parent
            radius: width / 2
            color: card.ink
            hovered: buttonMouse.containsMouse
            pressed: buttonMouse.pressed
            pressPoint: Qt.point(buttonMouse.mouseX, buttonMouse.mouseY)
        }
        MIcon {
            anchors.centerIn: parent
            size: 24
            source: mediaButton.icon
            color: card.ink
        }
        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mediaButton.clicked()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        anchors.bottomMargin: 8
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Kirigami.Icon {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                source: card.backend.mediaIconName
                visible: valid
            }
            MText {
                Layout.fillWidth: true
                role: "labelMedium"
                color: card.softInk
                text: card.backend.mediaIdentity
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 0
                MText {
                    Layout.fillWidth: true
                    role: "titleMedium"
                    color: card.ink
                    text: card.backend.mediaTrack
                }
                MText {
                    Layout.fillWidth: true
                    role: "bodyMedium"
                    color: card.softInk
                    text: card.backend.mediaArtist
                    visible: text.length > 0
                }
            }

            Rectangle {
                id: playButton
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 56
                implicitHeight: 56
                radius: card.backend.mediaPlaying && !M3.classic ? 16 : 28
                color: M3.primaryContainer
                opacity: card.backend.mediaCanPlayPause ? 1 : 0.38
                Behavior on radius {
                    NumberAnimation {
                        duration: M3.durationLong2
                        easing.type: Easing.Bezier
                        easing.bezierCurve: M3.easingEmphasized
                    }
                }
                Accessible.role: Accessible.Button
                Accessible.name: card.backend.mediaPlaying ? i18n("Pause") : i18n("Play")
                Accessible.onPressAction: card.backend.mediaPlayPause()

                MIcon {
                    anchors.centerIn: parent
                    size: 28
                    source: card.backend.mediaPlaying ? "media-playback-pause" : "media-playback-start"
                    color: M3.primaryContainerContent
                }
                MStateLayer {
                    anchors.fill: parent
                    radius: playButton.radius
                    color: M3.primaryContainerContent
                    hovered: playMouse.containsMouse
                    pressed: playMouse.pressed
                    pressPoint: Qt.point(playMouse.mouseX, playMouse.mouseY)
                }
                MouseArea {
                    id: playMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: card.backend.mediaCanPlayPause
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.backend.mediaPlayPause()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            MediaButton {
                icon: "media-skip-backward"
                text: i18n("Previous")
                enabled: card.backend.mediaCanPrevious
                onClicked: card.backend.mediaPrevious()
            }
            WavyProgress {
                id: seekBar
                Layout.fillWidth: true
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                color: card.hasArt ? "#ffffff" : M3.primary
                playing: card.backend.mediaPlaying
                interactive: card.backend.mediaCanSeek && card.backend.mediaLength > 0
                value: card.backend.mediaLength > 0 ? card.elapsed / card.backend.mediaLength : 0
                onSeekRequested: value => {
                    card.elapsed = value * card.backend.mediaLength;
                    card.backend.mediaSeek(card.elapsed);
                }

                MText {
                    anchors.bottom: parent.top
                    x: Math.max(0, Math.min(parent.width - width, parent.shownValue * parent.width - width / 2))
                    visible: seekBar.dragging
                    role: "labelMedium"
                    color: card.ink
                    text: card.time(seekBar.shownValue * card.backend.mediaLength)
                }
            }
            MediaButton {
                icon: "media-skip-forward"
                text: i18n("Next")
                enabled: card.backend.mediaCanNext
                onClicked: card.backend.mediaNext()
            }
        }
    }
}
