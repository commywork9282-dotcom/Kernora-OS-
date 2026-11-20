/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import io.calamares.core 1.0
import io.calamares.ui 1.0

import QtQuick
import QtQuick.Controls
import org.kernora.m3
import org.kernora.ui

PixelPage {
    id: page

    icon: "language"
    title: qsTr("Choose your language")
    description: qsTr("Kernora will use this language. You can change it later in Settings.")

    property string query
    property var regionNames: ({})
    property var zones: []

    function nameOf(code: string): string {
        const locale = Qt.locale(code.split(".")[0].split("@")[0]);
        let name = locale.nativeLanguageName;
        if (name.length === 0 || locale.name === "C") {
            return "";
        }
        name = name.charAt(0).toLocaleUpperCase() + name.slice(1);
        const territory = locale.nativeTerritoryName;
        return territory.length > 0 ? name + " (" + territory + ")" : name;
    }

    property bool formatsChosen: false

    readonly property var languages: {
        const seen = {};
        const list = [];
        for (const code of config.supportedLocales) {
            const name = nameOf(code);
            if (name.length > 0 && !seen[name]) {
                seen[name] = true;
                list.push({ code: code, name: name, country: code.split(".")[0].split("_")[1] || "" });
            }
        }
        list.sort((a, b) => a.name.localeCompare(b.name));
        return list;
    }

    readonly property var rows: {
        const needle = query.trim().toLocaleLowerCase();
        if (needle.length > 0) {
            return languages.filter(l => l.name.toLocaleLowerCase().indexOf(needle) >= 0 || l.code.toLowerCase().indexOf(needle) >= 0);
        }
        const country = config.currentLocation ? config.currentLocation.countryCode : "";
        const current = config.currentLanguageCode;
        const common = ["en", "ru", "uk", "de", "fr", "es", "pt", "it", "pl", "tr", "zh", "ja", "ko", "ar", "nl", "sv", "cs", "ro", "hu", "el", "he", "fi", "da", "nb", "kk", "be", "id", "vi", "th", "hi", "fa", "bg", "sr", "hr", "sk", "lt", "lv", "et", "ka", "hy", "az", "uz"];
        const major = l => common.indexOf(l.code.split("_")[0]) >= 0;
        const suggested = languages.filter(l => l.code === current || (country.length > 0 && l.country === country && major(l)) || l.code.indexOf("en_US") === 0);
        suggested.sort((a, b) => (b.code === current) - (a.code === current));
        const result = [{ header: qsTr("Suggested") }].concat(suggested.slice(0, 4));
        return result.concat([{ header: qsTr("All languages") }]).concat(languages);
    }

    Instantiator {
        model: config.regionModel
        delegate: QtObject {
            required property string name
            required property string key
            Component.onCompleted: {
                const names = Object.assign({}, page.regionNames);
                names[key] = name;
                page.regionNames = names;
            }
        }
    }

    Instantiator {
        id: zoneObjects
        model: config.zonesModel
        delegate: QtObject {
            required property string name
            required property string key
            required property string region
        }
        onObjectAdded: zoneTimer.restart()
    }

    Timer {
        id: zoneTimer
        interval: 0
        onTriggered: {
            const list = [];
            for (let i = 0; i < zoneObjects.count; ++i) {
                const zone = zoneObjects.objectAt(i);
                if (zone) {
                    list.push({ value: zone.region + "/" + zone.key, label: zone.name + ", " + (page.regionNames[zone.region] || zone.region) });
                }
            }
            list.sort((a, b) => a.label.localeCompare(b.label));
            page.zones = list;
        }
    }

    below: Group {
        width: parent ? parent.width : 400

        ListItem {
            title: qsTr("Time zone")
            subtitle: config.currentLocation ? config.currentLocation.name + ", " + (page.regionNames[config.currentLocation.region] || config.currentLocation.region) : ""
            icon: "preferences-system-time"
            iconStyle: "plain"
            chevron: true
            onClicked: zoneDialog.open()
        }

        ListItem {
            title: qsTr("Formats")
            subtitle: page.nameOf(config.currentLCCode) || config.currentLCStatus
            icon: "office-calendar"
            iconStyle: "plain"
            chevron: true
            onClicked: formatsDialog.open()
        }
    }

    Column {
        anchors.fill: parent
        spacing: 16

        SearchField {
            id: search
            width: parent.width
            placeholderText: qsTr("Search languages")
            onTextChanged: page.query = text
        }

        ListView {
            id: list

            width: parent.width
            height: parent.height - search.height - parent.spacing
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: page.rows
            ScrollBar.vertical: ScrollBar {}

            delegate: Item {
                id: row

                required property int index
                required property var modelData
                readonly property bool header: modelData.header !== undefined
                readonly property bool selected: !header && modelData.code === config.currentLanguageCode
                readonly property bool first: index === 0 || page.rows[index - 1].header !== undefined
                readonly property bool last: index === page.rows.length - 1 || page.rows[index + 1].header !== undefined

                width: list.width
                height: header ? (index === 0 ? 36 : 56) : 60

                MText {
                    visible: row.header
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 10
                    x: 4
                    role: "titleSmall"
                    text: row.header ? row.modelData.header : ""
                    color: M3.primary
                }

                Rectangle {
                    visible: !row.header
                    anchors.fill: parent
                    color: row.selected ? M3.secondaryContainer : M3.surfaceContainerHigh
                    topLeftRadius: row.first ? 24 : 6
                    topRightRadius: row.first ? 24 : 6
                    bottomLeftRadius: row.last ? 24 : 6
                    bottomRightRadius: row.last ? 24 : 6

                    MText {
                        x: 24
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 80
                        role: "bodyLarge"
                        text: row.header ? "" : row.modelData.name
                        horizontalAlignment: Text.AlignLeft
                        elide: Text.ElideRight
                        color: row.selected ? M3.secondaryContainerContent : M3.surfaceContent
                    }

                    MIcon {
                        visible: row.selected
                        anchors.right: parent.right
                        anchors.rightMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        size: 24
                        source: page.symbol("check")
                        color: M3.secondaryContainerContent
                    }

                    MStateLayer {
                        anchors.fill: parent
                        radius: 6
                        color: M3.surfaceContent
                        hovered: rowMouse.containsMouse
                        pressed: rowMouse.pressed
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            config.currentLanguageCode = row.modelData.code;
                            if (!page.formatsChosen) {
                                config.currentLCCode = row.modelData.code;
                            }
                        }
                    }
                }
            }
        }
    }

    ChoiceDialog {
        id: zoneDialog
        title: qsTr("Time zone")
        searchable: true
        options: page.zones
        currentValue: config.currentLocation ? config.currentLocation.region + "/" + config.currentLocation.zone : ""
        onChosen: value => {
            const cut = value.indexOf("/");
            config.setCurrentLocation(value.slice(0, cut), value.slice(cut + 1));
        }
    }

    ChoiceDialog {
        id: formatsDialog
        title: qsTr("Formats")
        searchable: true
        options: page.languages.map(l => ({ value: l.code, label: l.name }))
        currentValue: config.currentLCCode
        onChosen: value => {
            page.formatsChosen = true;
            config.currentLCCode = value;
        }
    }

    function onActivate() {}
    function onLeave() {}
}
