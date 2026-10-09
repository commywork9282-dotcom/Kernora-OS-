/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Dialogs as Dialogs
import QtCore
import org.kernora.m3
import org.kernora.ui as UI

ColumnLayout {
    id: root

    property string title
    property string cfg_folder
    property string cfg_shape
    property int cfg_minutes

    function tr(text: string): string {
        return i18nd("plasma_applet_org.kernora.widget.photo", text);
    }

    readonly property var shapes: ["cookie9", "sunny", "arch", "clover4", "flower", "heart", "circle", "puffy"]

    spacing: 16

    UI.Group {
        Layout.fillWidth: true
        title: root.tr("Shape")

        Flow {
            width: parent.width
            spacing: 12
            topPadding: 8
            bottomPadding: 8

            Repeater {
                model: root.shapes
                delegate: QQC2.AbstractButton {
                    id: tile
                    required property string modelData
                    width: 64
                    height: 64
                    onClicked: root.cfg_shape = modelData
                    background: Rectangle {
                        radius: 16
                        color: root.cfg_shape === tile.modelData ? M3.secondaryContainer : "transparent"
                        border.width: root.cfg_shape === tile.modelData ? 2 : 0
                        border.color: M3.primary
                    }
                    contentItem: MaterialShape {
                        anchors.fill: parent
                        anchors.margins: 10
                        shape: tile.modelData
                        color: M3.primary
                    }
                }
            }
        }
    }

    UI.Group {
        Layout.fillWidth: true
        title: root.tr("Pictures")

        UI.ListItem {
            title: root.tr("Folder")
            subtitle: root.cfg_folder.length > 0 ? decodeURIComponent(root.cfg_folder.replace("file://", "")) : root.tr("Pictures")
            icon: "folder"
            iconStyle: "plain"
            chevron: true
            onClicked: folderDialog.open()
        }
        UI.ChoiceItem {
            title: root.tr("Change the picture")
            icon: "chronometer"
            iconStyle: "plain"
            options: [
                { value: 5, label: root.tr("Every 5 minutes") },
                { value: 30, label: root.tr("Every 30 minutes") },
                { value: 120, label: root.tr("Every 2 hours") },
                { value: 1440, label: root.tr("Every day") }
            ]
            currentValue: root.cfg_minutes
            onSelected: value => root.cfg_minutes = value
        }
    }

    Dialogs.FolderDialog {
        id: folderDialog
        currentFolder: root.cfg_folder.length > 0 ? root.cfg_folder : StandardPaths.writableLocation(StandardPaths.PicturesLocation)
        onAccepted: root.cfg_folder = selectedFolder
    }
}
