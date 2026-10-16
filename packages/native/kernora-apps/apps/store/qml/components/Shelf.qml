/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kernora.m3
import org.kernora.store

Column {
    id: shelf

    property string title
    property string collection
    property string category
    property int limit: 0

    readonly property var app: QQC2.ApplicationWindow.window
    readonly property alias count: shelfModel.count

    spacing: 16
    visible: shelfModel.count > 0

    AppModel {
        id: shelfModel
        collection: shelf.collection
        category: shelf.collection.length > 0 ? "" : shelf.category
        limit: shelf.limit
    }

    Item {
        width: parent.width
        height: 40

        MouseArea {
            id: headerMouse
            width: Math.min(parent.width, heading.implicitWidth + 56)
            height: parent.height
            enabled: shelf.category.length > 0
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: shelf.app.openCategory(shelf.category)

            RowLayout {
                anchors.fill: parent
                spacing: 8
                MText {
                    id: heading
                    Layout.maximumWidth: shelf.width - 56
                    role: "titleLarge"
                    text: shelf.title
                    elide: Text.ElideRight
                }
                MIcon {
                    visible: shelf.category.length > 0
                    size: 24
                    source: Qt.application.layoutDirection === Qt.RightToLeft ? "go-previous" : "go-next"
                    color: headerMouse.containsMouse ? M3.primary : M3.surfaceVariantContent
                }
                Item { Layout.fillWidth: true }
            }
        }
    }

    Item {
        width: parent.width
        height: list.height

        HoverHandler { id: rowHover }

        ListView {
            id: list
            width: parent.width
            height: 202
            orientation: ListView.Horizontal
            spacing: 24
            clip: true
            leftMargin: 8
            rightMargin: 8
            boundsBehavior: Flickable.StopAtBounds
            model: shelfModel
            Behavior on contentX {
                enabled: !list.moving
                NumberAnimation { duration: M3.durationLong2; easing.type: Easing.Bezier; easing.bezierCurve: M3.easingEmphasized }
            }
            delegate: AppTile {
                required appId
                required name
                required summary
                required iconSource
                required installed
                required busy
                required hasUpdate
                required progress
                required rating
                y: 8
                onClicked: shelf.app.openApp(appId)
            }
        }

        MIconButton {
            anchors.left: parent.left
            y: 8 + 60 - height / 2
            variant: "tonal"
            icon: "go-previous"
            text: i18n("Back")
            opacity: rowHover.hovered && !list.atXBeginning ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: M3.durationShort4 } }
            onClicked: list.contentX = Math.max(list.originX - list.leftMargin, list.contentX - list.width * 0.8)
        }
        MIconButton {
            anchors.right: parent.right
            y: 8 + 60 - height / 2
            variant: "tonal"
            icon: "go-next"
            text: i18n("More")
            opacity: rowHover.hovered && !list.atXEnd ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: M3.durationShort4 } }
            onClicked: list.contentX = Math.min(list.contentWidth - list.width + list.originX + list.rightMargin, list.contentX + list.width * 0.8)
        }
    }
}
