/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import io.calamares.core 1.0
import io.calamares.ui 1.0

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kernora.m3
import org.kernora.ui

Item {
    id: locationPage

    Rectangle {
        anchors.fill: parent
        color: M3.surface
    }

    property string region: config.currentLocation ? config.currentLocation.region : ""
    Component.onCompleted: config.regionalZonesModel.region = region
    onRegionChanged: config.regionalZonesModel.region = region
    Connections {
        target: config.regionalZonesModel
        function onDataChanged() { sortCities.restart(); }
    }

    property var cities: []
    Instantiator {
        id: cityModel
        model: config.regionalZonesModel
        delegate: QtObject {
            required property string name
            required property string key
        }
        onObjectAdded: sortCities.restart()
        onObjectRemoved: sortCities.restart()
    }
    Timer {
        id: sortCities
        interval: 0
        onTriggered: {
            const list = [];
            for (let i = 0; i < cityModel.count; ++i) {
                const city = cityModel.objectAt(i);
                if (city) {
                    list.push({ name: city.name, key: city.key });
                }
            }
            list.sort((a, b) => a.name.localeCompare(b.name));
            locationPage.cities = list;
        }
    }
    onCitiesChanged: {
        const here = config.currentLocation;
        const zone = here && here.region === region ? here.zone : "";
        const index = cities.findIndex(city => city.key === zone);
        Qt.callLater(() => index >= 0 ? zones.positionViewAtIndex(index, ListView.Center) : zones.positionViewAtBeginning());
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 32
        anchors.rightMargin: 32
        anchors.topMargin: 24
        anchors.bottomMargin: 16
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            IconCircle {
                size: 48
                icon: "preferences-system-time"
                accent: 3
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                MText {
                    Layout.fillWidth: true
                    role: "headlineSmall"
                    text: config.currentLocation ? config.currentLocation.name : ""
                }
                MText {
                    Layout.fillWidth: true
                    role: "bodyMedium"
                    color: M3.surfaceVariantContent
                    text: config.currentTimezoneName
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: config.regionModel
                delegate: AbstractButton {
                    id: chip
                    required property string name
                    required property string key
                    readonly property bool chosen: key === locationPage.region
                    implicitWidth: chipLabel.implicitWidth + 32
                    implicitHeight: 34
                    onClicked: locationPage.region = key
                    background: Rectangle {
                        radius: 8
                        color: chip.chosen ? M3.secondaryContainer : "transparent"
                        border.width: chip.chosen ? 0 : 1
                        border.color: M3.outline
                        MStateLayer {
                            radius: 8
                            hovered: chip.hovered
                            pressed: chip.pressed
                        }
                    }
                    contentItem: MText {
                        id: chipLabel
                        role: "labelLarge"
                        horizontalAlignment: Text.AlignHCenter
                        text: chip.name
                        color: chip.chosen ? M3.secondaryContainerContent : M3.surfaceVariantContent
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 20
            color: M3.surfaceContainer
            clip: true

            ListView {
                id: zones
                anchors.fill: parent
                anchors.margins: 6
                model: locationPage.cities
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                delegate: RadioRow {
                    required property var modelData
                    width: zones.width
                    title: modelData.name
                    checked: config.currentLocation && config.currentLocation.region === locationPage.region
                        && config.currentLocation.zone === modelData.key
                    onClicked: config.setCurrentLocation(locationPage.region, modelData.key)
                }
            }
        }

        Group {
            Layout.fillWidth: true
            ListItem {
                title: config.currentLanguageStatus
                icon: "preferences-desktop-locale"
                iconStyle: "plain"
                maximumSubtitleLines: 2
                trailing: Component {
                    Button {
                        text: qsTr("Change", "@button")
                        onClicked: languageDialog.open()
                    }
                }
                interactive: false
            }
            ListItem {
                title: config.currentLCStatus
                icon: "office-calendar"
                iconStyle: "plain"
                trailing: Component {
                    Button {
                        text: qsTr("Change", "@button")
                        onClicked: formatsDialog.open()
                    }
                }
                interactive: false
            }
        }
    }

    ChoiceDialog {
        id: languageDialog
        title: config.currentLanguageStatus
        searchable: true
        options: config.supportedLocales.map(l => ({ value: l, label: l }))
        currentValue: config.currentLanguageCode
        onChosen: value => config.currentLanguageCode = value
    }
    ChoiceDialog {
        id: formatsDialog
        title: config.currentLCStatus
        searchable: true
        options: config.supportedLocales.map(l => ({ value: l, label: l }))
        currentValue: config.currentLCCode
        onChosen: value => config.currentLCCode = value
    }

    function onActivate() {}
    function onLeave() {}
}
