/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import org.kernora.m3
import org.kernora.ui
import org.kernora.store
import "components"

Item {
    id: page

    readonly property var app: QQC2.ApplicationWindow.window
    readonly property real contentWidth: Math.min(width - 48, 1200)

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight + 64
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: column
            x: (flick.width - page.contentWidth) / 2
            y: 24
            width: page.contentWidth
            spacing: 28

            Notice {
                width: parent.width
                visible: Store.live
                text: i18n("You are trying Kernora. Apps you install now disappear after a restart, install Kernora to keep them.")
            }

            Shelf {
                width: parent.width
                title: i18n("Chat & calls")
                collection: "chat"
                category: "internet"
            }
            Shelf {
                width: parent.width
                title: i18n("Music & video")
                collection: "media"
                category: "multimedia"
            }
            Shelf {
                width: parent.width
                title: i18n("Create")
                collection: "create"
                category: "graphics"
            }
            Shelf {
                width: parent.width
                title: i18n("Work & study")
                collection: "work"
                category: "office"
            }
            Shelf {
                width: parent.width
                title: Store.categoryName("development")
                category: "development"
                limit: 20
            }
            Shelf {
                width: parent.width
                title: Store.categoryName("education")
                category: "education"
                limit: 20
            }
            Shelf {
                width: parent.width
                title: Store.categoryName("utilities")
                category: "utilities"
                limit: 20
            }
        }
    }

    MScrollIndicator {
        flickable: flick
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
    }
}
