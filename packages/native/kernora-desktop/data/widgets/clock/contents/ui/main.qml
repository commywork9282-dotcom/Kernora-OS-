/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import "m3"

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    switchWidth: Plasmoid.configuration.placed ? 0 : 239
    switchHeight: Plasmoid.configuration.placed ? 0 : 249

    Timer {
        running: !Plasmoid.configuration.placed
        interval: 2000
        onTriggered: Plasmoid.configuration.placed = true
    }

    readonly property bool analog: Plasmoid.configuration.style === "analog"
    property date now: new Date()
    readonly property bool twelveHours: Qt.locale().timeFormat(Locale.ShortFormat).toLowerCase().indexOf("ap") >= 0

    toolTipMainText: Qt.locale().toString(now, Locale.LongFormat)
    toolTipSubText: ""

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    fullRepresentation: Item {
        Layout.preferredWidth: root.analog ? 220 : 240
        Layout.preferredHeight: root.analog ? 220 : 250
        Layout.minimumWidth: 100
        Layout.minimumHeight: 100

        Loader {
            anchors.fill: parent
            sourceComponent: root.analog ? analogFace : boldFace
        }
    }

    Component {
        id: boldFace

        Item {
            id: face
            readonly property real digit: Math.min(height * 0.5, width * 0.4)
            readonly property int hour: root.twelveHours ? (root.now.getHours() + 11) % 12 + 1 : root.now.getHours()

            Column {
                id: digits
                anchors.centerIn: parent
                spacing: -face.digit * 0.2
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "#000000"
                    shadowOpacity: 0.75
                    shadowBlur: 0.9
                    shadowScale: 1.04
                    shadowVerticalOffset: 2
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: String(face.hour).padStart(2, "0")
                    color: M3.darkScheme.primary
                    font.family: M3.typeface
                    font.pixelSize: face.digit
                    font.weight: Font.Medium
                    font.letterSpacing: -face.digit * 0.04
                    font.features: { "tnum": 1 }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: String(root.now.getMinutes()).padStart(2, "0")
                    color: M3.darkScheme.tertiary
                    font.family: M3.typeface
                    font.pixelSize: face.digit
                    font.weight: Font.Medium
                    font.letterSpacing: -face.digit * 0.04
                    font.features: { "tnum": 1 }
                }
            }
        }
    }

    Component {
        id: analogFace

        Item {
            id: dial
            readonly property real side: Math.min(width, height)
            readonly property real hours: root.now.getHours() % 12 + root.now.getMinutes() / 60
            readonly property real minutes: root.now.getMinutes() + root.now.getSeconds() / 60

            MaterialShape {
                anchors.fill: parent
                shape: "cookie12"
                color: M3.primaryContainer
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowOpacity: 0.3
                    shadowBlur: 0.5
                    shadowVerticalOffset: 2
                }
            }

            Repeater {
                model: 12
                delegate: Item {
                    required property int index
                    anchors.centerIn: parent
                    width: 0
                    height: 0
                    rotation: index * 30
                    Rectangle {
                        readonly property real dot: dial.side * (index % 3 === 0 ? 0.035 : 0.022)
                        width: dot
                        height: dot
                        radius: dot / 2
                        x: -dot / 2
                        y: -dial.side * 0.36 - dot / 2
                        color: M3.primaryContainerContent
                        opacity: index % 3 === 0 ? 0.9 : 0.5
                    }
                }
            }

            Hand {
                angle: dial.hours * 30
                length: dial.side * 0.24
                thickness: dial.side * 0.075
                color: M3.primary
            }
            Hand {
                angle: dial.minutes * 6
                length: dial.side * 0.34
                thickness: dial.side * 0.05
                color: M3.tertiary
            }
            Rectangle {
                anchors.centerIn: parent
                width: dial.side * 0.06
                height: width
                radius: width / 2
                color: M3.primaryContainerContent
            }
        }
    }

    component Hand: Item {
        id: hand
        property real angle
        property real length
        property real thickness
        property color color
        anchors.centerIn: parent
        width: 0
        height: 0
        rotation: angle

        Rectangle {
            x: -hand.thickness / 2
            y: -hand.length
            width: hand.thickness
            height: hand.length + hand.thickness / 2
            radius: hand.thickness / 2
            color: hand.color
        }
    }
}
