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
    property var pending: null
    property var results: []
    property bool searching: false
    property string message: ""

    signal changed()

    function tr(text: string): string {
        return i18nd(picker.domain, text);
    }

    property Settings store: Settings {
        location: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/kernorarc"
        category: "Weather"
    }

    function search(query: string): void {
        const name = query.trim();
        if (name.length < 2) {
            results = [];
            message = "";
            searching = false;
            return;
        }
        searching = true;
        message = "";
        const request = new XMLHttpRequest();
        const language = Qt.locale().name.split("_")[0];
        request.open("GET", "https://geocoding-api.open-meteo.com/v1/search?count=6&format=json&language=" + language
                     + "&name=" + encodeURIComponent(name));
        request.onreadystatechange = () => {
            if (request.readyState !== XMLHttpRequest.DONE || searchField.text.trim() !== name) {
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
        pending = { name: place.name, latitude: place.latitude, longitude: place.longitude };
        city = place.name;
        results = [];
        message = "";
        searchField.text = "";
        changed();
    }

    function forget(): void {
        pending = { name: "", latitude: 0, longitude: 0 };
        city = "";
        changed();
    }

    function commit(): void {
        if (!pending) {
            return;
        }
        store.setValue("city", pending.name);
        store.setValue("latitude", pending.latitude);
        store.setValue("longitude", pending.longitude);
        store.setValue("cacheTime", 0);
        store.sync();
        pending = null;
    }

    Timer {
        id: typing
        interval: 400
        onTriggered: picker.search(searchField.text)
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
        onTextChanged: typing.restart()
        onAccepted: {
            typing.stop();
            picker.search(text);
        }
        Keys.onReturnPressed: event => event.accepted = true
        Keys.onEnterPressed: event => event.accepted = true
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
