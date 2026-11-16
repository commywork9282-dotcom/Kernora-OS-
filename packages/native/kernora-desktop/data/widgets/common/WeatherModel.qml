/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtCore
import "weather.js" as Weather

QtObject {
    id: model

    readonly property int refreshMinutes: 25
    readonly property string cacheVersion: "2"
    readonly property bool fahrenheit: Qt.locale().measurementSystem === Locale.ImperialUSSystem

    property string city: ""
    property real latitude: 0
    property real longitude: 0
    readonly property bool configured: city.length > 0

    property bool ready: false
    property bool failed: false
    property real temperature: 0
    property real feelsLike: 0
    property var hours: []
    property var days: []
    property real high: 0
    property real low: 0
    property int code: 0
    property bool day: true
    readonly property string kind: Weather.kind(code)
    readonly property string icon: Weather.icon(kind, day)
    readonly property string shape: Weather.shape(kind)
    readonly property string degrees: Math.round(temperature) + "°"
    readonly property string condition: {
        switch (kind) {
        case "clear":
            return day ? i18n("Sunny") : i18n("Clear");
        case "mostly":
            return day ? i18n("Mostly sunny") : i18n("Mostly clear");
        case "partly":
            return i18n("Partly cloudy");
        case "fog":
            return i18n("Fog");
        case "rain":
            return i18n("Rain");
        case "snow":
            return i18n("Snow");
        case "storm":
            return i18n("Thunderstorm");
        default:
            return i18n("Cloudy");
        }
    }

    property Settings store: Settings {
        location: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/kernorarc"
        category: "Weather"
    }

    function apply(text: string): bool {
        try {
            const data = JSON.parse(text);
            const hourly = data.hourly;
            const daily = data.daily;
            const hours = [];
            for (let i = 0; i < hourly.time.length; ++i) {
                hours.push({ time: hourly.time[i], temperature: hourly.temperature_2m[i],
                             code: hourly.weather_code[i], day: hourly.is_day[i] === 1 });
            }
            const days = [];
            for (let i = 0; i < daily.time.length; ++i) {
                days.push({ date: daily.time[i], high: daily.temperature_2m_max[i], low: daily.temperature_2m_min[i],
                            code: daily.weather_code[i] });
            }
            model.temperature = data.current.temperature_2m;
            model.feelsLike = data.current.apparent_temperature;
            model.code = data.current.weather_code;
            model.day = data.current.is_day === 1;
            model.high = daily.temperature_2m_max[0];
            model.low = daily.temperature_2m_min[0];
            model.hours = hours;
            model.days = days;
            model.ready = true;
            model.failed = false;
            return true;
        } catch (error) {
            return false;
        }
    }

    function reload(): void {
        store.sync();
        city = String(store.value("city", ""));
        latitude = Number(store.value("latitude", 0));
        longitude = Number(store.value("longitude", 0));
        if (!configured) {
            ready = false;
            return;
        }
        const cached = String(store.value("cache", ""));
        const unit = String(store.value("cacheUnit", ""));
        const fresh = Date.now() - Number(store.value("cacheTime", 0)) < refreshMinutes * 60000
            && String(store.value("cacheVersion", "")) === model.cacheVersion;
        const sameUnit = unit === (fahrenheit ? "fahrenheit" : "celsius");
        if (cached.length > 0 && sameUnit && String(store.value("cachePlace", "")) === city) {
            apply(cached);
        }
        if (!fresh || !sameUnit || String(store.value("cachePlace", "")) !== city) {
            fetch();
        }
    }

    function fetch(): void {
        const request = new XMLHttpRequest();
        const place = city;
        request.open("GET", "https://api.open-meteo.com/v1/forecast?latitude=" + latitude + "&longitude=" + longitude
                     + "&current=temperature_2m,apparent_temperature,weather_code,is_day"
                     + "&hourly=temperature_2m,weather_code,is_day&forecast_hours=8"
                     + "&daily=weather_code,temperature_2m_max,temperature_2m_min"
                     + "&timezone=auto&forecast_days=7" + (fahrenheit ? "&temperature_unit=fahrenheit" : ""));
        request.onreadystatechange = () => {
            if (request.readyState !== XMLHttpRequest.DONE) {
                return;
            }
            if (request.status === 200 && model.apply(request.responseText)) {
                model.store.setValue("cache", request.responseText);
                model.store.setValue("cacheTime", Date.now());
                model.store.setValue("cacheUnit", model.fahrenheit ? "fahrenheit" : "celsius");
                model.store.setValue("cachePlace", place);
                model.store.setValue("cacheVersion", model.cacheVersion);
                model.store.sync();
            } else if (!model.ready) {
                model.failed = true;
            }
        };
        request.send();
    }

    property Timer watch: Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            model.store.sync();
            if (String(model.store.value("city", "")) !== model.city
                    || Number(model.store.value("latitude", 0)) !== model.latitude
                    || Number(model.store.value("longitude", 0)) !== model.longitude) {
                model.ready = false;
                model.failed = false;
                model.reload();
            }
        }
    }

    property Timer poll: Timer {
        interval: 5 * 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: model.reload()
    }
}
