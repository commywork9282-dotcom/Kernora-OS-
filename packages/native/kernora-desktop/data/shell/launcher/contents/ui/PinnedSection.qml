/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import "m3"

Column {
    id: root

    property var model: null
    property int columns: 6
    property real reveal: 1

    signal launch(var model, int index)
    signal menuRequested(Item tile, real x, real y, string favoriteId)
    signal dropped()

    readonly property bool hasPinned: pinned.count > 0

    spacing: 8
    bottomPadding: 4

    MText {
        x: 12
        role: M3.classic ? "labelLarge" : "titleSmall"
        color: M3.classic ? M3.surfaceVariantContent : M3.primary
        text: i18n("Pinned")
        visible: root.hasPinned
        opacity: root.reveal
    }

    Rectangle {
        width: root.width
        height: visible ? 112 + 8 : 0
        radius: M3.classic ? M3.cornerCard : 28
        color: M3.surfaceContainerHigh
        visible: root.hasPinned
        opacity: root.reveal

        Row {
            anchors.fill: parent
            anchors.margins: 4

            Repeater {
                id: pinned
                model: root.model

                delegate: AppTile {
                    id: pinnedTile
                    required property int index
                    required property var model
                    width: Math.floor((root.width - 8) / root.columns)
                    height: 112
                    visible: index < root.columns
                    name: model.display ?? ""
                    iconSource: model.decoration ?? ""
                    favoriteId: model.favoriteId ?? ""
                    url: model.url ?? ""
                    reveal: root.reveal
                    onDropped: root.dropped()
                    onClicked: root.launch(root.model, index)
                    onMenuRequested: (x, y) => root.menuRequested(pinnedTile, x, y, favoriteId)
                }
            }
        }
    }

    MText {
        x: 12
        topPadding: root.hasPinned ? 8 : 0
        role: M3.classic ? "labelLarge" : "titleSmall"
        color: M3.classic ? M3.surfaceVariantContent : M3.primary
        text: i18n("All apps")
        opacity: root.reveal
    }
}
