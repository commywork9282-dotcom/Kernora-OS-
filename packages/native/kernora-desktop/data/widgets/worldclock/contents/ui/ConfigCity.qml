/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kernora.m3
import org.kernora.ui as UI
import org.kde.plasma.private.digitalclock as DigitalClock

ColumnLayout {
    id: page

    property string title
    property string cfg_timeZone
    property string cfg_timeZoneDefault

    property string query: ""
    readonly property bool searching: query.length > 0

    function tr(text: string): string {
        return i18nd("plasma_applet_org.kernora.widget.worldclock", text);
    }

    spacing: 12

    property var zoneList: []
    readonly property var matches: {
        const text = page.query.toLowerCase();
        if (text.length === 0) {
            return [];
        }
        const first = [];
        const rest = [];
        for (const zone of page.zoneList) {
            const city = zone.city.toLowerCase();
            const english = zone.id.toLowerCase().replace(/_/g, " ");
            const name = english.substring(english.lastIndexOf("/") + 1);
            if (city.startsWith(text) || name.startsWith(text)) {
                first.push(zone);
            } else if (city.indexOf(text) >= 0 || english.indexOf(text) >= 0 || zone.place.toLowerCase().indexOf(text) >= 0) {
                rest.push(zone);
            }
        }
        return first.concat(rest).slice(0, 8);
    }

    Instantiator {
        id: zoneReader
        model: DigitalClock.TimeZoneModel {}
        delegate: QtObject {
            required property string timeZoneId
            required property string city
            required property string region
            required property string comment
            required property bool isLocalTimeZone
        }
        onObjectAdded: gather.restart()
    }

    Timer {
        id: gather
        interval: 50
        onTriggered: {
            const list = [];
            for (let i = 0; i < zoneReader.count; ++i) {
                const zone = zoneReader.objectAt(i);
                if (zone && !zone.isLocalTimeZone && zone.timeZoneId.indexOf("/") > 0) {
                    list.push({ id: zone.timeZoneId, city: zone.city,
                                place: zone.comment.length > 0 ? zone.comment : DigitalClock.TimeZonesI18n.i18nContinents(zone.region) });
                }
            }
            page.zoneList = list;
        }
    }

    Timer {
        id: typing
        interval: 300
        onTriggered: page.query = searchField.text.trim()
    }

    UI.Group {
        Layout.fillWidth: true
        note: page.cfg_timeZone.length === 0 ? page.tr("Until you choose a city, the widget shows the local time.") : ""

        UI.ListItem {
            visible: page.cfg_timeZone.length > 0
            title: DigitalClock.TimeZonesI18n.i18nCity(page.cfg_timeZone)
            subtitle: {
                const zone = page.zoneList.find(entry => entry.id === page.cfg_timeZone);
                return zone ? zone.place : "";
            }
            icon: "globe"
            iconStyle: "plain"
        }
    }

    UI.SearchField {
        id: searchField
        Layout.fillWidth: true
        placeholderText: page.cfg_timeZone.length > 0 ? page.tr("Choose another city") : page.tr("Search for a city")
        onTextChanged: typing.restart()
        onAccepted: {
            typing.stop();
            page.query = text.trim();
        }
        Keys.onReturnPressed: event => event.accepted = true
        Keys.onEnterPressed: event => event.accepted = true
    }

    Repeater {
        id: results
        model: page.matches

        delegate: UI.ListItem {
            required property var modelData

            Layout.fillWidth: true
            title: modelData.city
            subtitle: modelData.place
            icon: "globe"
            iconStyle: "plain"
            onClicked: {
                page.cfg_timeZone = modelData.id;
                searchField.text = "";
                typing.stop();
                page.query = "";
            }
        }
    }

    MText {
        Layout.fillWidth: true
        visible: page.searching && results.count === 0
        role: "bodyMedium"
        color: M3.surfaceVariantContent
        wrapMode: Text.Wrap
        text: page.tr("No city with this name.")
    }

    Item {
        Layout.fillHeight: true
    }
}
