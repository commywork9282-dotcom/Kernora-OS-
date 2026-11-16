/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import "weather.js" as Weather

PlasmoidItem {
    id: root

    readonly property bool inPanel: Plasmoid.formFactor !== PlasmaCore.Types.Planar
    preferredRepresentation: inPanel ? null : fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    switchWidth: Plasmoid.configuration.placed ? 0 : 120
    switchHeight: Plasmoid.configuration.placed ? 0 : 120

    Timer {
        running: !Plasmoid.configuration.placed
        interval: 2000
        onTriggered: Plasmoid.configuration.placed = true
    }

    readonly property string style: Plasmoid.configuration.style === "forecast" ? "forecast" : "current"
    readonly property bool twelveHours: Qt.locale().timeFormat(Locale.ShortFormat).toLowerCase().indexOf("ap") >= 0

    toolTipMainText: weather.configured ? weather.city : i18n("Weather")
    toolTipSubText: weather.ready ? weather.condition : ""

    WeatherModel {
        id: weather
    }

    function hourLabel(time: string): string {
        const hour = Number(String(time).substring(11, 13));
        if (root.twelveHours) {
            return (hour % 12 === 0 ? 12 : hour % 12) + " " + (hour < 12 ? Qt.locale().amText : Qt.locale().pmText);
        }
        return String(hour).padStart(2, "0") + ":00";
    }

    function dayLabel(date: string): string {
        const day = new Date(String(date) + "T12:00:00");
        const name = Qt.locale().standaloneDayName(day.getDay(), Locale.LongFormat);
        return name.charAt(0).toUpperCase() + name.slice(1);
    }

    readonly property var hourItems: {
        const items = [{ label: i18n("Now"), temperature: weather.temperature, kind: weather.kind, day: weather.day }];
        for (let i = 1; i < weather.hours.length; ++i) {
            const hour = weather.hours[i];
            items.push({ label: root.hourLabel(hour.time), temperature: hour.temperature, kind: Weather.kind(hour.code),
                         day: hour.day });
        }
        return items;
    }

    readonly property var dayItems: weather.days.slice(1).map(entry => ({
        label: root.dayLabel(entry.date),
        high: entry.high,
        low: entry.low,
        kind: Weather.kind(entry.code)
    }))

    fullRepresentation: Item {
        LiftHandler {}

        Layout.preferredWidth: root.inPanel ? (root.style === "forecast" ? 416 : 272) : -1
        Layout.preferredHeight: root.inPanel ? 287 : -1
        Layout.minimumWidth: 120
        Layout.minimumHeight: 120
        Layout.maximumWidth: root.inPanel ? Layout.preferredWidth : Infinity
        Layout.maximumHeight: root.inPanel ? Layout.preferredHeight : Infinity

        WeatherFace {
            anchors.fill: parent
            style: root.style
            ready: weather.ready
            message: !weather.configured ? i18n("Choose a city")
                : weather.failed ? i18n("No connection to the weather service") : i18n("Loading…")
            temperature: weather.temperature
            feelsLike: weather.feelsLike
            high: weather.high
            low: weather.low
            kind: weather.kind
            day: weather.day
            city: weather.city
            condition: weather.condition
            hours: root.hourItems
            days: root.dayItems
            feelsText: i18n("Feels like %1", Math.round(weather.feelsLike) + "°")
            sourceText: i18n("Source: Open-Meteo")
        }

        MouseArea {
            anchors.fill: parent
            enabled: !weather.configured
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: Plasmoid.internalAction("configure").trigger()
        }
    }
}
