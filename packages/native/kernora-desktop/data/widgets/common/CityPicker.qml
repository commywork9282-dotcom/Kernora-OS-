/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtCore
import org.kernora.m3
import org.kernora.ui as UI

ColumnLayout {
    id: picker

    property string domain
    property string city: ""
    property var results: []
    property bool searching: false
    property string message: ""

    function tr(text: string): string {
        return i18nd(picker.domain, text);
    }

    property Settings store: Settings {
        location: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/kernorarc"
        category: "Weather"
    }

    function search(query: string): void {
        const name = query.trim();
        if (name.length === 0) {
            return;
        }
        searching = true;
        message = "";
        const request = new XMLHttpRequest();
        const language = Qt.locale().name.split("_")[0];
        request.open("GET", "https://geocoding-api.open-meteo.com/v1/search?count=6&format=json&language=" + language
                     + "&name=" + encodeURIComponent(name));
        request.onreadystatechange = () => {
            if (request.readyState !== XMLHttpRequest.DONE) {
                return;
            }
            picker.searching = false;
            if (request.status !== 200) {
                picker.results = [];
                picker.message = picker.tr("The weather service could not be reached.");
                return;
            }
            try {
                picker.results = JSON.parse(request.responseText).results || [];
            } catch (error) {
                picker.results = [];
            }
            picker.message = picker.results.length === 0 ? picker.tr("No place with this name.") : "";
        };
        request.send();
    }

    function choose(place: var): void {
        store.setValue("city", place.name);
        store.setValue("latitude", place.latitude);
        store.setValue("longitude", place.longitude);
        store.setValue("cacheTime", 0);
        store.sync();
        city = place.name;
        results = [];
        searchField.text = "";
    }

    function forget(): void {
        store.setValue("city", "");
        store.sync();
        city = "";
    }

    Component.onCompleted: {
        store.sync();
        city = String(store.value("city", ""));
    }

    spacing: 12

    UI.Group {
        Layout.fillWidth: true
        title: picker.tr("Location")
        note: picker.tr("Every Kernora weather widget uses this place. Forecasts come from Open-Meteo.com.")

        UI.ListItem {
            visible: picker.city.length > 0
            title: picker.city
            subtitle: picker.tr("Remove")
            icon: "globe"
            iconStyle: "plain"
            onClicked: picker.forget()
        }
    }

    UI.SearchField {
        id: searchField
        Layout.fillWidth: true
        placeholderText: picker.city.length > 0 ? picker.tr("Choose another city") : picker.tr("Search for a city")
        onAccepted: picker.search(text)
    }

    Repeater {
        model: picker.results
        delegate: UI.ListItem {
            required property var modelData
            Layout.fillWidth: true
            title: modelData.name
            subtitle: [modelData.admin1, modelData.country].filter(part => !!part).join(", ")
            icon: "globe"
            iconStyle: "plain"
            onClicked: picker.choose(modelData)
        }
    }

    MText {
        Layout.fillWidth: true
        visible: text.length > 0
        role: "bodyMedium"
        color: M3.surfaceVariantContent
        wrapMode: Text.Wrap
        text: picker.searching ? picker.tr("Searching…") : picker.message
    }
}
