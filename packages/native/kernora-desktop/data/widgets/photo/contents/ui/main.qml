/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtCore
import Qt.labs.folderlistmodel
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import "m3"

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    switchWidth: Plasmoid.configuration.placed ? 0 : 229
    switchHeight: Plasmoid.configuration.placed ? 0 : 229

    Timer {
        running: !Plasmoid.configuration.placed
        interval: 2000
        onTriggered: Plasmoid.configuration.placed = true
    }

    readonly property url folder: Plasmoid.configuration.folder.length > 0
        ? Plasmoid.configuration.folder : StandardPaths.writableLocation(StandardPaths.PicturesLocation)
    property url current

    toolTipMainText: i18n("Photo")
    toolTipSubText: ""

    function pick(): void {
        if (pictures.count === 0) {
            current = "";
            return;
        }
        let index = Math.floor(Math.random() * pictures.count);
        if (pictures.count > 1 && pictures.get(index, "fileUrl") === current) {
            index = (index + 1) % pictures.count;
        }
        current = pictures.get(index, "fileUrl");
    }

    FolderListModel {
        id: pictures
        folder: root.folder
        showDirs: false
        caseSensitive: false
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.avif"]
        onStatusChanged: {
            if (status === FolderListModel.Ready) {
                root.pick();
            }
        }
    }

    Timer {
        interval: Math.max(1, Plasmoid.configuration.minutes) * 60000
        running: pictures.count > 1
        repeat: true
        onTriggered: root.pick()
    }

    fullRepresentation: Item {
        id: frame
        Layout.preferredWidth: 230
        Layout.preferredHeight: 230
        Layout.minimumWidth: 120
        Layout.minimumHeight: 120

        readonly property bool shown: photo.status === Image.Ready

        Image {
            id: photo
            anchors.fill: parent
            source: root.current
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize: Qt.size(Math.max(width, height) * 2, Math.max(width, height) * 2)
            visible: false
        }
        MaterialShape {
            id: mask
            anchors.fill: parent
            shape: Plasmoid.configuration.shape
            color: "white"
            visible: false
            layer.enabled: true
        }
        MultiEffect {
            anchors.fill: parent
            visible: frame.shown
            source: photo
            maskEnabled: true
            maskSource: mask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }

        MaterialShape {
            anchors.fill: parent
            visible: !frame.shown
            shape: Plasmoid.configuration.shape
            color: M3.primaryContainer
        }
        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(frame.width, frame.height) * 0.6
            visible: !frame.shown
            spacing: 6

            MIcon {
                Layout.alignment: Qt.AlignHCenter
                size: 32
                source: "image-x-generic"
                color: M3.primaryContainerContent
            }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: i18n("Put pictures in the Pictures folder")
                color: M3.primaryContainerContent
                font.family: M3.typeface
                font.pixelSize: 13
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: frame.shown ? Qt.openUrlExternally(root.current) : Plasmoid.internalAction("configure").trigger()
        }
    }
}
