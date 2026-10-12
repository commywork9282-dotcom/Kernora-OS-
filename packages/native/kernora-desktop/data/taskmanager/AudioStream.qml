/*
    SPDX-FileCopyrightText: 2017 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kernora.m3

Item {
    id: audioStreamIconBox

    readonly property bool shown: Plasmoid.configuration.interactiveMute
    readonly property real side: Math.round(Math.max(14, Math.min(iconBox.width, iconBox.height) * 0.44))

    width: side
    height: side
    z: 10
    anchors {
        top: iconBox.top
        right: iconBox.right
        topMargin: -Math.round(side * 0.08)
        rightMargin: -Math.round(side * 0.08)
    }

    activeFocusOnTab: shown

    states: [
        State {
            name: "playing"
            when: audioStreamIconBox.shown && task.playingAudio && !task.muted
            PropertyChanges {
                target: audioStreamIconBox
                opacity: 1
            }
            PropertyChanges {
                target: audioStreamIcon
                source: "audio-volume-high-symbolic"
            }
        },
        State {
            name: "muted"
            when: audioStreamIconBox.shown && task.muted
            PropertyChanges {
                target: audioStreamIconBox
                opacity: 1
            }
            PropertyChanges {
                target: audioStreamIcon
                source: "audio-volume-muted-symbolic"
            }
        }
    ]

    transitions: [
        Transition {
            from: ""
            to: "playing"
            SequentialAnimation {
                PauseAnimation {
                    duration: !task.delayAudioStreamIndicator || inPopup ? 0 : 2000
                }
                NumberAnimation {
                    property: "opacity"
                    duration: M3.durationMedium2
                }
            }
        },
        Transition {
            from: ""
            to: "muted"
            NumberAnimation {
                property: "opacity"
                duration: M3.durationMedium2
            }
        },
        Transition {
            to: ""
            NumberAnimation {
                property: "opacity"
                duration: M3.durationShort4
            }
        }
    ]

    opacity: 0
    visible: opacity > 0

    Keys.onReturnPressed: event => toggleMuted()
    Keys.onEnterPressed: event => Keys.returnPressed(event)
    Keys.onSpacePressed: event => Keys.returnPressed(event)

    Accessible.checkable: true
    Accessible.checked: task.muted
    Accessible.name: task.muted ? i18nc("@action:button", "Unmute") : i18nc("@action:button", "Mute")
    Accessible.description: task.muted ? i18nc("@info:tooltip %1 is the window title", "Unmute %1", model.display) : i18nc("@info:tooltip %1 is the window title", "Mute %1", model.display)
    Accessible.role: Accessible.Button

    HoverHandler {
        id: hoverHandler
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: tapHandler
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: (eventPoint, button) => toggleMuted()
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: tapHandler.pressed ? M3.primaryContainer : M3.primary
        border.width: Math.max(1, Math.round(width * 0.1))
        border.color: M3.surfaceContainer
        scale: hoverHandler.hovered || audioStreamIconBox.activeFocus ? 1.12 : 1
        Behavior on scale {
            NumberAnimation {
                duration: M3.durationShort4
            }
        }
    }

    Kirigami.Icon {
        id: audioStreamIcon
        anchors.centerIn: parent
        width: Math.round(parent.width * 0.62)
        height: width
        source: "audio-volume-high-symbolic"
        isMask: true
        color: tapHandler.pressed ? M3.primaryContainerContent : M3.primaryContent
    }
}
