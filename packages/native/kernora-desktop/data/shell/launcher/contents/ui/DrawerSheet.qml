/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami
import "m3"

FocusScope {
    id: sheet

    property QtObject launcher: null
    property var appsModel: null
    property real reveal: 1
    property bool frosted: false

    readonly property alias query: input.text
    readonly property string trimmedQuery: query.trim()
    readonly property bool searching: trimmedQuery.length > 0
    readonly property int columns: 6
    readonly property int sidePadding: 16
    readonly property int cellWidth: Math.floor((width - sidePadding * 2) / columns)
    readonly property int cellHeight: 96

    property var letters: []
    property bool dragging: false

    Timer {
        id: settle
        interval: 450
    }

    signal requestClose()
    signal dragStarted()
    signal dragFinished()

    function prepare(byKey: bool): void {
        settle.restart();
        menu.close();
        input.clear();
        grid.currentIndex = -1;
        grid.positionViewAtBeginning();
        results.currentIndex = 0;
        if (byKey) {
            input.forceActiveFocus();
        } else {
            grid.forceActiveFocus();
        }
    }

    function dropDrag(): void {
        dragging = false;
    }

    function launch(model: var, index: int): void {
        if (model && index >= 0 && model.trigger(index, "", null)) {
            sheet.requestClose();
        }
    }

    function forwardToSearch(event: var): bool {
        if (event.text.length > 0 && event.text.trim().length > 0
                && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
            input.forceActiveFocus();
            input.insert(input.cursorPosition, event.text);
            return true;
        }
        return false;
    }

    function rebuildLetters(): void {
        const list = [];
        const model = sheet.appsModel;
        const count = model ? model.count : 0;
        for (let i = 0; i < count; ++i) {
            const name = String(model.data(model.index(i, 0), Qt.DisplayRole) || "");
            list.push(name.length > 0 ? name.charAt(0).toLocaleUpperCase() : "");
        }
        letters = list;
    }

    function letterAt(fraction: real): string {
        if (letters.length === 0) {
            return "";
        }
        const index = grid.indexAt(grid.cellWidth / 2, grid.contentY + grid.cellHeight / 2);
        return index >= 0 ? letters[Math.min(letters.length - 1, index)] || "" : "";
    }

    onAppsModelChanged: rebuildLetters()
    Connections {
        target: sheet.appsModel
        ignoreUnknownSignals: true
        function onCountChanged(): void {
            sheet.rebuildLetters();
        }
        function onModelReset(): void {
            sheet.rebuildLetters();
        }
    }

    function showMenu(tile: Item, model: var, index: int, storageId: string, url: string, actions: var): void {
        const own = [];
        let desktopAction = null;
        for (const action of actions || []) {
            if (action.actionId === "_kicker_jumpListAction") {
                const named = action.icon && String(action.icon).length > 0;
                own.push({ icon: named ? action.icon : "window-new", colorful: named, text: action.text,
                           action: () => sheet.launchAction(model, index, action) });
            } else if (action.actionId === "addToDesktop") {
                desktopAction = action;
            }
        }
        const system = [];
        const tasks = sheet.launcher ? sheet.launcher.taskManager() : null;
        const launcherUrl = storageId.length > 0 ? "applications:" + storageId : url;
        if (tasks && launcherUrl.length > 0) {
            const pinned = tasks.hasLauncher(launcherUrl) || (url.length > 0 && tasks.hasLauncher(url));
            system.push(pinned
                ? { icon: "window-unpin", text: i18n("Remove from taskbar"), action: () => {
                        tasks.removeLauncher(launcherUrl);
                        if (url.length > 0) {
                            tasks.removeLauncher(url);
                        }
                    } }
                : { icon: "window-pin", text: i18n("Add to taskbar"), action: () => tasks.addLauncher(launcherUrl) });
        }
        if (desktopAction) {
            system.push({ icon: "go-home", text: i18n("Add to Home screen"),
                          action: () => model.trigger(index, desktopAction.actionId, desktopAction.actionArgument) });
        }
        if (storageId.length > 0 && sheet.launcher) {
            system.push({ icon: "dialog-information", text: i18n("App info"), action: () => {
                sheet.launcher.showAppInfo(storageId);
                sheet.requestClose();
            } });
        }
        const groups = [];
        if (own.length > 0) {
            groups.push(own);
        }
        if (system.length > 0) {
            groups.push(system);
        }
        if (groups.length === 0) {
            return;
        }
        menu.groups = groups;
        menu.openFor(tile, 10, 44);
    }

    function launchAction(model: var, index: int, action: var): void {
        if (model.trigger(index, action.actionId, action.actionArgument)) {
            sheet.requestClose();
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onWheel: wheel => wheel.accepted = true
    }

    Kirigami.ShadowedRectangle {
        anchors.fill: parent
        radius: 28
        color: sheet.frosted ? M3.withAlpha(M3.surfaceContainerHigh, 0.62) : M3.surfaceContainerHighest
        border.width: sheet.frosted ? 1 : 0
        border.color: M3.withAlpha(M3.surfaceContainerLowest, 0.45)
        shadow.size: sheet.frosted ? 0 : 28
        shadow.yOffset: 8
        shadow.color: Qt.rgba(0, 0, 0, M3.dark ? 0.4 : 0.2)
    }

    Rectangle {
        id: searchPill
        x: 28
        y: 40
        width: parent.width - 56
        height: 48
        radius: 24
        color: M3.dark ? M3.surfaceContainer : M3.withAlpha(M3.surfaceContainerLowest, sheet.frosted ? 0.9 : 1)

        Kirigami.Icon {
            id: browserIcon
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 24
            height: 24
            source: "librewolf"
            animated: false
        }

        TextInput {
            id: input
            anchors.left: browserIcon.right
            anchors.leftMargin: 14
            anchors.right: clearButton.visible ? clearButton.left : parent.right
            anchors.rightMargin: clearButton.visible ? 4 : 20
            anchors.verticalCenter: parent.verticalCenter
            font: M3.bodyLarge
            color: M3.surfaceContent
            selectionColor: M3.primary
            selectedTextColor: M3.primaryContent
            clip: true
            selectByMouse: true
            renderType: Text.QtRendering

            Keys.onDownPressed: {
                if (sheet.searching) {
                    results.move(1);
                } else {
                    grid.forceActiveFocus();
                    grid.currentIndex = 0;
                }
            }
            Keys.onUpPressed: {
                if (sheet.searching) {
                    results.move(-1);
                }
            }
            Keys.onTabPressed: {
                if (sheet.searching) {
                    results.move(1);
                }
            }
            Keys.onBacktabPressed: {
                if (sheet.searching) {
                    results.move(-1);
                }
            }
            Keys.onReturnPressed: sheet.activateCurrent()
            Keys.onEnterPressed: sheet.activateCurrent()
            Keys.onEscapePressed: event => {
                if (text.length > 0) {
                    clear();
                } else {
                    sheet.requestClose();
                }
            }

            MText {
                anchors.verticalCenter: parent.verticalCenter
                role: "bodyLarge"
                text: i18n("Search web and more")
                color: M3.surfaceVariantContent
                visible: input.text.length === 0 && !input.preeditText
            }
        }

        MIconButton {
            id: clearButton
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            icon: "edit-clear"
            text: i18n("Clear search")
            visible: input.text.length > 0
            activeFocusOnTab: false
            onClicked: {
                input.clear();
                input.forceActiveFocus();
            }
        }

        MouseArea {
            anchors.fill: parent
            anchors.rightMargin: clearButton.visible ? clearButton.width + 4 : 0
            cursorShape: Qt.IBeamCursor
            onPressed: event => {
                input.forceActiveFocus();
                event.accepted = false;
            }
        }
    }

    function scrollGrid(dy: real): void {
        const top = grid.originY - grid.topMargin;
        const bottom = Math.max(top, grid.originY + grid.contentHeight + grid.bottomMargin - grid.height);
        grid.contentY = Math.max(top, Math.min(bottom, grid.contentY + dy));
    }

    function activateCurrent(): void {
        if (searching) {
            results.activate(results.currentIndex);
        } else if (grid.count > 0) {
            launch(grid.model, Math.max(0, grid.currentIndex));
        }
    }

    Item {
        id: body
        anchors.top: searchPill.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        clip: true

        GridView {
            id: grid

            anchors.fill: parent
            anchors.leftMargin: sheet.sidePadding
            anchors.rightMargin: sheet.sidePadding
            topMargin: 20
            bottomMargin: 4
            visible: opacity > 0
            opacity: sheet.searching ? 0 : 1
            Behavior on opacity {
                NumberAnimation {
                    duration: M3.durationShort4
                }
            }

            model: sheet.appsModel
            cellWidth: sheet.cellWidth
            cellHeight: sheet.cellHeight
            currentIndex: -1
            keyNavigationWraps: false
            highlightFollowsCurrentItem: false
            boundsBehavior: Flickable.StopAtBounds
            reuseItems: false
            interactive: false
            onCurrentIndexChanged: {
                if (currentIndex >= 0) {
                    positionViewAtIndex(currentIndex, GridView.Contain);
                }
            }

            delegate: DrawerTile {
                id: tile
                required property int index
                required property var model
                width: grid.cellWidth
                height: grid.cellHeight
                name: model.display ?? ""
                iconSource: model.decoration ?? ""
                url: model.url ?? ""
                current: GridView.isCurrentItem && grid.activeFocus
                onClicked: sheet.launch(grid.model, index)
                onMenuRequested: (x, y) => sheet.showMenu(tile, grid.model, index, model.favoriteId ?? "",
                                                         String(model.url ?? ""), model.actionList ?? [])
                onDragStarted: {
                    menu.close();
                    sheet.dragging = true;
                    sheet.dragStarted();
                }
                onDragFinished: dropped => {
                    sheet.dragging = false;
                    sheet.dragFinished();
                }
            }

            Keys.onUpPressed: event => {
                if (currentIndex < sheet.columns) {
                    currentIndex = -1;
                    input.forceActiveFocus();
                } else {
                    moveCurrentIndexUp();
                }
            }
            Keys.onReturnPressed: sheet.launch(model, currentIndex)
            Keys.onEnterPressed: sheet.launch(model, currentIndex)
            Keys.onEscapePressed: sheet.requestClose()
            Keys.onPressed: event => {
                event.accepted = sheet.forwardToSearch(event);
            }

            WheelHandler {
                property real travel: 0
                target: null
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    event.accepted = true;
                    if (settle.running) {
                        return;
                    }
                    const smooth = event.pixelDelta.y !== 0;
                    const delta = smooth ? event.pixelDelta.y : event.angleDelta.y / 120 * sheet.cellHeight * 0.75;
                    if (smooth && grid.atYBeginning && delta > 0) {
                        travel += delta;
                        if (travel > 120) {
                            travel = 0;
                            sheet.requestClose();
                        }
                        return;
                    }
                    travel = 0;
                    sheet.scrollGrid(-delta);
                }
            }

            DragHandler {
                property real startY: 0
                target: null
                acceptedDevices: PointerDevice.TouchScreen
                xAxis.enabled: false
                onActiveChanged: if (active) startY = grid.contentY
                onTranslationChanged: if (active) sheet.scrollGrid(startY - translation.y - grid.contentY)
            }
        }

        DrawerResults {
            id: results
            anchors.fill: parent
            visible: opacity > 0
            opacity: sheet.searching ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: M3.durationShort4
                }
            }
            launcher: sheet.launcher
            query: sheet.trimmedQuery
            columns: sheet.columns
            cellWidth: sheet.cellWidth
            cellHeight: sheet.cellHeight
            onLaunched: sheet.requestClose()
            onSearchWeb: text => {
                if (sheet.launcher) {
                    sheet.launcher.searchWeb(text);
                }
                sheet.requestClose();
            }
            onSearchStore: text => {
                if (sheet.launcher) {
                    sheet.launcher.searchStore(text);
                }
                sheet.requestClose();
            }
        }

        DrawerScroller {
            anchors.right: parent.right
            anchors.rightMargin: 0
            anchors.top: parent.top
            anchors.topMargin: 16
            anchors.bottom: parent.bottom
            flickable: sheet.searching ? results : grid
            letterAt: sheet.searching ? null : sheet.letterAt
        }
    }

    DrawerMenu {
        id: menu
        parent: sheet.parent
        onClosed: {
            if (!input.activeFocus && !grid.activeFocus) {
                (sheet.searching ? input : grid).forceActiveFocus();
            }
        }
    }
}
