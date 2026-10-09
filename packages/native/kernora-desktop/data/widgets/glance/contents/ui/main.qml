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

    switchWidth: Plasmoid.configuration.placed ? 0 : 439
    switchHeight: Plasmoid.configuration.placed ? 0 : 109

    Timer {
        running: !Plasmoid.configuration.placed
        interval: 2000
        onTriggered: Plasmoid.configuration.placed = true
    }

    property date now: new Date()
    readonly property bool showWeather: Plasmoid.configuration.showWeather && weather.configured && weather.ready
    readonly property string date: {
        const text = Qt.locale().toString(now, "ddd, d MMMM");
        return text.charAt(0).toUpperCase() + text.slice(1);
    }
    readonly property string detail: {
        if (battery.hasBattery && battery.charging) {
            return i18n("Charging · %1%", battery.batteryPercent);
        }
        if (battery.hasBattery && battery.batteryPercent <= 20) {
            return i18n("Battery low · %1%", battery.batteryPercent);
        }
        if (showWeather) {
            return i18n("%1 · %2° / %3°", weather.condition, Math.round(weather.high), Math.round(weather.low));
        }
        return "";
    }

    toolTipMainText: Qt.locale().toString(now, Locale.LongFormat)
    toolTipSubText: ""

    WeatherModel {
        id: weather
    }
    BatterySource {
        id: battery
    }
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    fullRepresentation: Item {
        id: glance
        Layout.preferredWidth: 440
        Layout.preferredHeight: 110
        Layout.minimumWidth: 200
        Layout.minimumHeight: 64

        readonly property real line: Math.max(18, Math.min(height * 0.36, width * 0.075))

        ColumnLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 8
            spacing: glance.line * 0.15
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#000000"
                shadowOpacity: 0.7
                shadowBlur: 0.8
                shadowVerticalOffset: 1
            }

            RowLayout {
                spacing: glance.line * 0.45

                Text {
                    text: root.date
                    color: "#ffffff"
                    font.family: M3.typeface
                    font.pixelSize: glance.line
                    elide: Text.ElideRight
                    Layout.maximumWidth: glance.width * 0.62
                }
                Rectangle {
                    visible: root.showWeather
                    implicitWidth: 2
                    implicitHeight: glance.line * 0.9
                    radius: 1
                    color: Qt.rgba(1, 1, 1, 0.7)
                }
                MIcon {
                    visible: root.showWeather
                    size: Math.round(glance.line * 1.05)
                    source: weather.icon
                    color: "#ffffff"
                }
                Text {
                    visible: root.showWeather
                    text: weather.degrees
                    color: "#ffffff"
                    font.family: M3.typeface
                    font.pixelSize: glance.line
                }
            }
            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.detail
                color: Qt.rgba(1, 1, 1, 0.9)
                font.family: M3.typeface
                font.pixelSize: Math.round(glance.line * 0.5)
                elide: Text.ElideRight
            }
        }
    }
}
