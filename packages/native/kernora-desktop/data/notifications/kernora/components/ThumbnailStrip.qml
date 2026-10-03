/*
    SPDX-FileCopyrightText: 2016 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2024 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

import org.kde.kquickcontrolsaddons as KQCAddons

import org.kde.plasma.private.notifications as Notifications

import org.kernora.m3
import org.kernora.ui

import "../global"

ColumnLayout {
    id: thumbnailArea

    property ModelInterface modelInterface

    property var urls: modelInterface.urls

    readonly property alias menuOpen: fileMenu.visible
    readonly property alias dragging: dragArea.dragging

    spacing: 8

    Notifications.FileMenu {
        id: fileMenu
        url: thumbnailer.url
        visualParent: menuButton
        onActionTriggered: action => modelInterface.fileActionInvoked(action)
    }

    Notifications.Thumbnailer {
        id: thumbnailer

        readonly property real ratio: pixmapSize.height ? pixmapSize.width / pixmapSize.height : 1

        url: urls[0]
        size: Qt.size(Globals.popupWidth, Globals.popupWidth)
    }

    RoundedClip {
        id: tile
        Layout.fillWidth: true
        Layout.preferredHeight: 160
        radius: M3.classic ? M3.cornerImage : 16

        Rectangle {
            anchors.fill: parent
            color: M3.surfaceContainerHighest
        }

        KQCAddons.QPixmapItem {
            id: previewBackground
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            layer.enabled: true
            opacity: 0.25
            pixmap: thumbnailer.pixmap
            layer.effect: FastBlur {
                source: previewBackground
                anchors.fill: previewBackground
                radius: 30
            }
        }

        KQCAddons.QPixmapItem {
            id: previewPixmap
            anchors.fill: parent
            pixmap: thumbnailer.pixmap
            smooth: true
            fillMode: Image.PreserveAspectFit
        }

        Kirigami.Icon {
            id: previewIcon
            anchors.centerIn: parent
            width: height
            height: 64
            active: dragArea.hovered
            source: !thumbnailer.busy && !thumbnailer.hasPreview ? thumbnailer.iconName : ""
        }

        PlasmaComponents3.BusyIndicator {
            anchors.centerIn: parent
            running: thumbnailer.busy
            visible: thumbnailer.busy
        }

        DraggableFileArea {
            id: dragArea
            anchors.fill: parent
            dragParent: previewIcon
            dragPixmapSize: previewIcon.height
            dragPixmap: thumbnailer.hasPreview ? thumbnailer.pixmap : thumbnailer.iconName
            dragUrl: thumbnailer.url

            onActivated: modelInterface.openUrl(thumbnailer.url)
            onContextMenuRequested: (pos) => {
                fileMenu.visualParent = this;
                fileMenu.open(pos.x, pos.y);
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        ActionContainer {
            id: actionContainer
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            modelInterface: thumbnailArea.modelInterface
            visible: (modelInterface.actionNames || []).length > 0 || modelInterface.hasReplyAction
        }

        Item {
            Layout.fillWidth: !actionContainer.visible
        }

        MIconButton {
            id: menuButton
            Layout.alignment: Qt.AlignTop
            icon: "application-menu"
            text: i18nd("plasma_applet_org.kde.plasma.notifications", "More Options…")
            onClicked: {
                fileMenu.visualParent = menuButton;
                fileMenu.open(-1, -1);
            }
        }
    }
}
