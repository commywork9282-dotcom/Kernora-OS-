/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kernora.ui as UI
import "m3"

FocusScope {
    id: root

    property var appsModel: null
    property var pinnedModel: null
    property var resultsModel: null

    property string userName
    property url userFace
    property bool canLock: true
    property bool canLogout: true
    property bool canShutdown: true

    readonly property alias query: search.text
    readonly property bool searching: query.length > 0

    signal launch(var model, int index)
    signal requestClose()
    signal openSettings()
    signal lockScreen()
    signal logOut()
    signal shutDown()
    signal restart()

    readonly property int columns: Math.max(4, Math.floor((width - 16) / 116))

    readonly property real idealHeight: 56 + 12
        + (grid.headerItem ? grid.headerItem.height : 0)
        + Math.ceil(grid.count / columns) * grid.cellHeight
        + 12 + 48

    implicitWidth: 760
    implicitHeight: 640

    function reset(): void {
        search.clear();
        grid.currentIndex = -1;
        results.currentIndex = 0;
        grid.positionViewAtBeginning();
        search.input.forceActiveFocus();
        entrance.restart();
    }

    function launchAt(model: var, index: int): void {
        if (model && index >= 0) {
            root.launch(model, index);
        }
    }

    Keys.onEscapePressed: requestClose()

    MMenu {
        id: tileMenu
        parent: root
    }

    function showTileMenu(tile: Item, x: real, y: real, favoriteId: string): void {
        if (!favoriteId || !pinnedModel) {
            return;
        }
        const pinned = pinnedModel.isFavorite(favoriteId);
        tileMenu.items = [{
            icon: pinned ? "window-unpin" : "window-pin",
            text: pinned ? i18n("Unpin") : i18n("Pin to launcher"),
            action: () => {
                if (pinned) {
                    pinnedModel.removeFavorite(favoriteId);
                } else {
                    pinnedModel.addFavorite(favoriteId, -1);
                }
            }
        }];
        tileMenu.openAt(tile, x, y);
    }

    function forwardToSearch(event: var): bool {
        if (event.text.length > 0 && event.text.trim().length > 0
                && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
            search.input.forceActiveFocus();
            search.text += event.text;
            return true;
        }
        return false;
    }

    property real reveal: 1
    NumberAnimation {
        id: entrance
        target: root
        property: "reveal"
        from: 0
        to: 1
        duration: M3.durationLong2
        easing.type: Easing.Bezier
        easing.bezierCurve: M3.easingEmphasizedDecelerate
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        MSearchBar {
            id: search
            Layout.fillWidth: true
            focus: true
            placeholderText: i18n("Search apps, settings and more")
            opacity: root.reveal
            transform: Translate { y: (1 - root.reveal) * -12 }

            onAccepted: {
                if (root.searching) {
                    root.launchAt(results.model, Math.max(0, results.currentIndex));
                } else if (grid.count > 0) {
                    root.launchAt(grid.model, Math.max(0, grid.currentIndex));
                }
            }
            onNavigateDown: {
                if (root.searching) {
                    results.forceActiveFocus();
                    results.currentIndex = Math.min(results.count - 1, results.currentIndex + 1);
                } else {
                    grid.forceActiveFocus();
                    grid.currentIndex = 0;
                }
            }
            onTextChanged: results.currentIndex = 0
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            GridView {
                id: grid

                anchors.fill: parent
                visible: opacity > 0
                opacity: root.searching ? 0 : 1
                scale: root.searching ? 0.98 : 1
                Behavior on opacity { NumberAnimation { duration: M3.durationShort4 } }
                Behavior on scale { NumberAnimation { duration: M3.durationMedium1; easing.type: Easing.OutCubic } }

                model: root.appsModel
                cellWidth: Math.floor(width / root.columns)
                cellHeight: 112
                currentIndex: -1
                keyNavigationWraps: false
                highlightFollowsCurrentItem: false
                boundsBehavior: Flickable.StopAtBounds
                reuseItems: false

                header: PinnedSection {
                    width: grid.width
                    model: root.pinnedModel
                    columns: root.columns
                    reveal: root.reveal
                    onLaunch: (model, index) => root.launchAt(model, index)
                    onMenuRequested: (tile, x, y, favoriteId) => root.showTileMenu(tile, x, y, favoriteId)
                    onDropped: root.requestClose()
                }

                delegate: AppTile {
                    id: appTile
                    required property int index
                    required property var model
                    width: grid.cellWidth
                    height: grid.cellHeight
                    name: model.display ?? ""
                    iconSource: model.decoration ?? ""
                    favoriteId: model.favoriteId ?? ""
                    url: model.url ?? ""
                    current: GridView.isCurrentItem && grid.activeFocus
                    enterDelay: Math.min(Math.floor(index / root.columns), 6) * 0.06
                    reveal: root.reveal
                    onClicked: root.launchAt(grid.model, index)
                    onMenuRequested: (x, y) => root.showTileMenu(appTile, x, y, favoriteId)
                    onDropped: root.requestClose()
                }

                Keys.onUpPressed: event => {
                    if (currentIndex < root.columns) {
                        currentIndex = -1;
                        search.input.forceActiveFocus();
                    } else {
                        moveCurrentIndexUp();
                    }
                }
                Keys.onReturnPressed: root.launchAt(model, currentIndex)
                Keys.onEnterPressed: root.launchAt(model, currentIndex)
                Keys.onPressed: event => {
                    event.accepted = root.forwardToSearch(event);
                }
            }

            ListView {
                id: results

                anchors.fill: parent
                visible: opacity > 0
                opacity: root.searching ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: M3.durationShort4 } }

                model: root.searching ? root.resultsModel : null
                spacing: 2
                currentIndex: 0
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 0

                delegate: ResultRow {
                    required property int index
                    required property var model
                    width: results.width
                    title: model.display ?? ""
                    subtitle: model.description ?? ""
                    iconSource: model.decoration ?? ""
                    current: ListView.isCurrentItem
                    onClicked: root.launchAt(results.model, index)
                }

                Keys.onUpPressed: {
                    if (currentIndex <= 0) {
                        search.input.forceActiveFocus();
                    } else {
                        decrementCurrentIndex();
                    }
                }
                Keys.onReturnPressed: root.launchAt(model, currentIndex)
                Keys.onEnterPressed: root.launchAt(model, currentIndex)
                Keys.onPressed: event => {
                    event.accepted = root.forwardToSearch(event);
                }

                MText {
                    anchors.centerIn: parent
                    role: "bodyLarge"
                    color: M3.surfaceVariantContent
                    visible: root.searching && results.count === 0
                    text: i18n("Nothing matches “%1”", root.query)
                }
            }

            MScrollIndicator {
                flickable: grid
                visible: scrollable && grid.visible
            }
            MScrollIndicator {
                flickable: results
                visible: scrollable && results.visible
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            spacing: 4
            opacity: root.reveal

            UI.Avatar {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                size: 40
                source: root.userFace
                initials: root.userName.length > 0 ? root.userName.charAt(0).toUpperCase() : ""
            }

            MText {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                role: "titleSmall"
                text: root.userName
            }

            MIconButton {
                icon: "configure"
                text: i18n("System Settings")
                onClicked: root.openSettings()
            }
            MIconButton {
                icon: "system-lock-screen"
                text: i18n("Lock")
                visible: M3.classic && root.canLock
                onClicked: root.lockScreen()
            }
            MIconButton {
                icon: "system-log-out"
                text: i18n("Log Out")
                visible: M3.classic && root.canLogout
                onClicked: root.logOut()
            }
            MIconButton {
                icon: "system-reboot"
                text: i18n("Restart")
                visible: M3.classic && root.canShutdown
                onClicked: root.restart()
            }
            MIconButton {
                icon: "system-shutdown"
                variant: "tonal"
                text: i18n("Shut Down…")
                visible: M3.classic && root.canShutdown
                onClicked: root.shutDown()
            }
            SessionGroup {
                visible: !M3.classic
                Layout.leftMargin: 4
                actions: [
                    { icon: "system-lock-screen", text: i18n("Lock"), visible: root.canLock, trigger: () => root.lockScreen() },
                    { icon: "system-log-out", text: i18n("Log Out"), visible: root.canLogout, trigger: () => root.logOut() },
                    { icon: "system-reboot", text: i18n("Restart"), visible: root.canShutdown, trigger: () => root.restart() },
                    { icon: "system-shutdown", text: i18n("Shut Down…"), visible: root.canShutdown, primary: true, trigger: () => root.shutDown() }
                ]
            }
        }
    }
}
