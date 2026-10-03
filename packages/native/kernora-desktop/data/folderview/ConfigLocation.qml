/*
    SPDX-FileCopyrightText: 2014 Eike Hein <hein@kde.org>
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.private.desktopcontainment.folder as Folder
import org.kernora.m3
import org.kernora.ui as UI

Item {
    id: configLocation

    property string cfg_url
    property int cfg_labelMode
    property string cfg_labelText
    property bool titleVisible: Plasmoid.containment != Plasmoid

    property string kind: ""
    property int placeIndex: -1

    implicitHeight: content.implicitHeight + 24

    function tr(text: string): string {
        return i18nd("kernora-ui", text);
    }
    function plain(text: string): string {
        return text.replace(/\s*[:：]\s*$/, "");
    }

    onCfg_urlChanged: applyConfig()
    Component.onCompleted: applyConfig()

    function applyConfig(force) {
        if (!force && kind !== "") {
            return;
        }

        if (cfg_url === "desktop:/") {
            kind = "desktop";
        } else if (cfg_url === "activities:/current/") {
            kind = "activity";
        } else {
            const placeForUrl = placesModel.indexForUrl(cfg_url);

            if (placeForUrl !== -1) {
                placeIndex = placeForUrl;
                kind = "place";
            } else {
                customPath.text = cfg_url;
                kind = "custom";
            }
        }
    }

    function choose(newKind: string): void {
        kind = newKind;
        if (newKind === "desktop") {
            cfg_url = "desktop:/";
        } else if (newKind === "activity") {
            cfg_url = "activities:/current/";
        } else if (newKind === "place") {
            if (placeIndex === -1 && places.count > 0) {
                placeIndex = 0;
            }
            if (placeIndex !== -1) {
                cfg_url = Folder.DesktopSchemeHelper.getDesktopUrl(placesModel.urlForIndex(placeIndex));
            }
        } else if (newKind === "custom" && customPath.text !== "") {
            cfg_url = Folder.DesktopSchemeHelper.getDesktopUrl(customPath.text);
        }
    }

    Folder.PlacesModel {
        id: placesModel
        showDesktopEntry: false

        onPlacesChanged: configLocation.applyConfig(true)
    }

    Instantiator {
        id: places
        model: placesModel
        delegate: QtObject {
            required property int index
            required property string display
        }
        readonly property var options: {
            const list = [];
            for (let i = 0; i < count; ++i) {
                const place = objectAt(i);
                if (place) {
                    list.push({ value: i, label: place.display });
                }
            }
            return list;
        }
    }

    Folder.DirectoryPicker {
        id: directoryPicker

        onUrlChanged: {
            customPath.text = Folder.DesktopSchemeHelper.getDesktopUrl(url);
        }
    }

    UI.ChoiceDialog {
        id: placeDialog
        title: configLocation.tr("Place")
        options: places.options
        currentValue: configLocation.placeIndex
        onChosen: value => {
            configLocation.placeIndex = value;
            configLocation.choose("place");
        }
    }

    ColumnLayout {
        id: content
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        spacing: 20

        UI.Group {
            Layout.fillWidth: true
            title: configLocation.plain(i18n("Show:"))

            UI.RadioRow {
                width: parent ? parent.width : implicitWidth
                title: configLocation.tr("Desktop folder")
                checked: configLocation.kind === "desktop"
                onClicked: configLocation.choose("desktop")
            }
            UI.RadioRow {
                width: parent ? parent.width : implicitWidth
                visible: placesModel.activityLinkingEnabled
                title: i18n("Files linked to the current activity")
                checked: configLocation.kind === "activity"
                onClicked: configLocation.choose("activity")
            }
            UI.RadioRow {
                width: parent ? parent.width : implicitWidth
                title: configLocation.tr("A place")
                subtitle: {
                    const place = places.options.find(o => o.value === configLocation.placeIndex);
                    return place ? place.label : configLocation.tr("Choose from Places");
                }
                checked: configLocation.kind === "place"
                onClicked: placeDialog.open()
            }
            UI.RadioRow {
                width: parent ? parent.width : implicitWidth
                title: configLocation.tr("Another folder")
                subtitle: configLocation.kind === "custom" ? "" : configLocation.tr("A path or a web address")
                checked: configLocation.kind === "custom"
                onClicked: {
                    configLocation.choose("custom");
                    customPath.forceActiveFocus();
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 4
            visible: configLocation.kind === "custom"
            spacing: 8

            UI.InputField {
                id: customPath
                Layout.fillWidth: true
                label: i18n("Type path or URL…")
                input.inputMethodHints: Qt.ImhNoPredictiveText

                onTextChanged: {
                    if (configLocation.kind === "custom" && text !== "") {
                        configLocation.cfg_url = Folder.DesktopSchemeHelper.getDesktopUrl(text);
                    }
                }
            }
            UI.IconButton {
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: 8
                iconName: "document-open-folder"
                text: configLocation.tr("Choose a folder")
                onClicked: directoryPicker.open()
            }
        }

        UI.Group {
            Layout.fillWidth: true
            visible: configLocation.titleVisible
            title: configLocation.plain(i18n("Title:"))

            Repeater {
                model: [i18n("None"), i18n("Default"), i18n("Full path"), i18n("Custom title")]
                delegate: UI.RadioRow {
                    width: parent ? parent.width : implicitWidth
                    required property int index
                    required property string modelData
                    title: modelData
                    checked: configLocation.cfg_labelMode === index
                    onClicked: configLocation.cfg_labelMode = index
                }
            }
        }

        UI.InputField {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 4
            visible: configLocation.titleVisible && configLocation.cfg_labelMode === 3
            label: i18n("Enter custom title…")
            text: configLocation.cfg_labelText
            onTextChanged: configLocation.cfg_labelText = text
        }
    }
}
