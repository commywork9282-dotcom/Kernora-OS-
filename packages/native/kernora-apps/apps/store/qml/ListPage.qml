/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kernora.m3
import org.kernora.ui
import org.kernora.store
import "components"

Item {
    id: page

    property string title
    property string category
    property int filter: Store.All
    property bool searching: false

    readonly property var app: QQC2.ApplicationWindow.window
    readonly property real contentWidth: Math.min(width - 48, 1180)
    readonly property int columns: Math.max(1, Math.floor((contentWidth + 12) / 352))

    AppModel {
        id: results
        category: page.category
        filter: page.filter
        search: page.searching && page.app ? page.app.searchText : ""
    }

    GridView {
        id: grid

        anchors.fill: parent
        anchors.leftMargin: (page.width - page.contentWidth) / 2
        anchors.rightMargin: anchors.leftMargin - 12
        cellWidth: (page.contentWidth + 12) / page.columns
        cellHeight: 124
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: 600
        model: results

        header: Item {
            width: page.contentWidth
            height: heading.implicitHeight + 52

            RowLayout {
                id: heading
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 28
                spacing: 8

                IconButton {
                    visible: page.app && page.app.narrow
                    iconName: "go-previous"
                    text: i18n("Back")
                    onClicked: page.app.goBack()
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    MText {
                        Layout.fillWidth: true
                        role: "headlineLarge"
                        text: page.searching ? i18n("Results for “%1”", page.app ? page.app.searchText.trim() : "") : page.title
                        elide: Text.ElideRight
                    }
                    MText {
                        Layout.fillWidth: true
                        role: "bodyLarge"
                        color: M3.surfaceVariantContent
                        visible: results.total > 0
                        text: page.filter === Store.Installed ? i18np("%1 app installed", "%1 apps installed", results.total)
                            : i18np("%1 app", "%1 apps", results.total)
                    }
                }
            }
        }

        footer: Item {
            width: page.contentWidth
            height: 24
        }

        delegate: Item {
            id: cell

            required property string appId
            required property string name
            required property string summary
            required property string developer
            required property string iconSource
            required property bool installed
            required property bool busy
            required property bool hasUpdate
            required property bool verified
            required property int progress
            required property real rating

            width: grid.cellWidth
            height: grid.cellHeight

            AppCard {
                anchors.fill: parent
                anchors.rightMargin: 12
                anchors.bottomMargin: 12
                appId: cell.appId
                name: cell.name
                summary: cell.summary
                developer: cell.developer
                iconSource: cell.iconSource
                installed: cell.installed
                busy: cell.busy
                hasUpdate: cell.hasUpdate
                verified: cell.verified
                progress: cell.progress
                rating: cell.rating
                onClicked: page.app.openApp(cell.appId)
            }
        }
    }

    MScrollIndicator {
        flickable: grid
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
    }

    EmptyState {
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 420)
        visible: Store.ready && results.count === 0 && (!page.searching || (page.app && page.app.searchText.trim().length > 0))
        icon: page.filter === Store.Installed ? "view-app-grid" : "search"
        title: page.filter === Store.Installed ? i18n("No apps from the store yet")
            : page.searching ? i18n("Nothing found") : i18n("This category is empty")
        text: page.filter === Store.Installed ? i18n("Apps you install from the store appear here.")
            : page.searching ? i18n("Try another name or a shorter word.") : ""
    }
}
