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

    switchWidth: Plasmoid.configuration.placed ? 0 : 209
    switchHeight: Plasmoid.configuration.placed ? 0 : 209

    Timer {
        running: !Plasmoid.configuration.placed
        interval: 2000
        onTriggered: Plasmoid.configuration.placed = true
    }

    toolTipMainText: weather.configured ? weather.city : i18n("Weather")
    toolTipSubText: weather.ready ? weather.condition : ""

    WeatherModel {
        id: weather
    }

    fullRepresentation: Item {
        id: card
        Layout.preferredWidth: 210
        Layout.preferredHeight: 210
        Layout.minimumWidth: 120
        Layout.minimumHeight: 120

        readonly property real side: Math.min(width, height)

        MaterialShape {
            id: backdrop
            anchors.fill: parent
            shape: weather.ready ? weather.shape : "cookie9"
            color: M3.primaryContainer
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowOpacity: 0.3
                shadowBlur: 0.5
                shadowVerticalOffset: 2
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: card.side * 0.6
            spacing: 0
            visible: weather.ready

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: weather.city
                color: M3.primaryContainerContent
                font.family: M3.typeface
                font.pixelSize: Math.round(card.side * 0.06)
                font.weight: Font.Medium
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: Math.round(card.side * 0.045)
                elide: Text.ElideRight
            }
            MIcon {
                Layout.alignment: Qt.AlignHCenter
                size: Math.round(card.side * 0.13)
                source: weather.icon
                color: M3.primaryContainerContent
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: weather.degrees
                color: M3.primaryContainerContent
                font.family: M3.typeface
                font.pixelSize: Math.round(card.side * 0.24)
                font.weight: Font.Medium
            }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: weather.condition
                color: M3.primaryContainerContent
                font.family: M3.typeface
                font.pixelSize: Math.round(card.side * 0.075)
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: Math.round(card.side * 0.05)
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: Math.round(weather.high) + "° / " + Math.round(weather.low) + "°"
                color: M3.primaryContainerContent
                opacity: 0.8
                font.family: M3.typeface
                font.pixelSize: Math.round(card.side * 0.06)
                elide: Text.ElideRight
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: card.side * 0.66
            spacing: 6
            visible: !weather.ready

            MIcon {
                Layout.alignment: Qt.AlignHCenter
                size: Math.round(card.side * 0.2)
                source: "weather-few-clouds"
                color: M3.primaryContainerContent
            }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: !weather.configured ? i18n("Choose a city")
                    : weather.failed ? i18n("No connection to the weather service") : i18n("Loading…")
                color: M3.primaryContainerContent
                font.family: M3.typeface
                font.pixelSize: Math.round(card.side * 0.075)
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: !weather.configured
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: Plasmoid.internalAction("configure").trigger()
        }
    }
}
