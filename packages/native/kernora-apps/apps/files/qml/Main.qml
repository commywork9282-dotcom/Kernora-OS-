/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import Qt.labs.folderlistmodel
import org.kernora.m3
import org.kernora.ui
import org.kernora.system
import org.kde.notification
import org.kde.kirigami as Kirigami
import "kinds.js" as Kinds

AppWindow {
    id: app

    title: folderName
    width: 1120
    height: 740
    minimumWidth: 420
    minimumHeight: 420
    color: M3.surfaceContainer
    visible: true

    readonly property bool narrow: width < 760
    readonly property string homePath: String(Files.standardFolder("home")).replace(/^file:\/\//, "")
    readonly property string trashPath: String(Files.trashFolder()).replace(/^file:\/\//, "")

    property url folder: Files.standardFolder("home")
    readonly property string folderPath: decodeURIComponent(String(folder).replace(/^file:\/\//, "")).replace(/\/$/, "") || "/"
    readonly property bool inTrash: folderPath === trashPath
    readonly property string folderName: inTrash ? i18n("Trash") : folderPath === homePath ? i18n("Home") : (folderPath.split("/").pop() || i18n("Computer"))

    property var history: []
    property int historyIndex: -1

    ConfigEntry { id: viewMode; file: "kernora-filesrc"; group: "View"; key: "Mode"; defaultValue: "grid" }
    ConfigEntry { id: sortField; file: "kernora-filesrc"; group: "View"; key: "Sort"; defaultValue: 1 }
    ConfigEntry { id: sortReversed; file: "kernora-filesrc"; group: "View"; key: "Reversed"; defaultValue: false }
    ConfigEntry { id: showHidden; file: "kernora-filesrc"; group: "View"; key: "ShowHidden"; defaultValue: false }
    readonly property bool listMode: viewMode.value === "list"
    function isOn(entry: var): bool {
        return entry.value === true || entry.value === "true";
    }

    function toUrl(path: string): string {
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }

    function go(url: var): void {
        const target = String(url);
        if (target === String(folder)) {
            return;
        }
        history = history.slice(0, historyIndex + 1).concat([target]);
        historyIndex = history.length - 1;
        setFolder(target);
    }
    function setFolder(url: string): void {
        folder = url;
        clearSelection();
        filter.text = "";
        view.currentIndex = -1;
    }
    function back(): void {
        if (historyIndex > 0) {
            historyIndex -= 1;
            setFolder(history[historyIndex]);
        }
    }
    function forward(): void {
        if (historyIndex < history.length - 1) {
            historyIndex += 1;
            setFolder(history[historyIndex]);
        }
    }
    function up(): void {
        if (folderPath !== "/") {
            go(toUrl(folderPath.slice(0, folderPath.lastIndexOf("/")) || "/"));
        }
    }

    function handleArguments(args: var): void {
        for (const argument of args || []) {
            const url = String(argument);
            if (!url.startsWith("file:")) {
                continue;
            }
            const info = Files.info(url);
            if (info.isDir) {
                go(url);
            } else if (info.exists) {
                go(info.folder);
                selectAfterLoad = url;
            }
            return;
        }
    }
    property string selectAfterLoad: ""

    Component.onCompleted: {
        history = [String(folder)];
        historyIndex = 0;
        handleArguments(startArguments);
    }

    FolderListModel {
        id: folderModel
        folder: app.folder
        showDirsFirst: true
        showHidden: app.isOn(showHidden)
        showDotAndDotDot: false
        caseSensitive: false
        sortCaseSensitive: false
        sortField: Number(sortField.value)
        sortReversed: app.isOn(sortReversed)
        nameFilters: filter.text.trim().length > 0 ? ["*" + filter.text.trim() + "*"] : []
        onStatusChanged: {
            if (status === FolderListModel.Ready && app.selectAfterLoad.length > 0) {
                const row = indexOf(app.selectAfterLoad);
                if (row >= 0) {
                    app.selectOnly(row);
                    view.currentIndex = row;
                    view.positionViewAtIndex(row, ItemView.Contain);
                }
                app.selectAfterLoad = "";
            }
        }
    }

    property var selected: ({})
    property int anchorRow: -1
    readonly property int selectedCount: Object.keys(selected).length

    function clearSelection(): void {
        selected = {};
        anchorRow = -1;
    }
    function selectOnly(row: int): void {
        const next = {};
        next[String(folderModel.get(row, "fileUrl"))] = true;
        selected = next;
        anchorRow = row;
    }
    function toggle(row: int): void {
        const key = String(folderModel.get(row, "fileUrl"));
        const next = Object.assign({}, selected);
        if (next[key]) {
            delete next[key];
        } else {
            next[key] = true;
        }
        selected = next;
        anchorRow = row;
    }
    function selectRange(to: int): void {
        const from = anchorRow < 0 ? to : anchorRow;
        const next = {};
        for (let i = Math.min(from, to); i <= Math.max(from, to); ++i) {
            next[String(folderModel.get(i, "fileUrl"))] = true;
        }
        selected = next;
    }
    function selectAll(): void {
        const next = {};
        for (let i = 0; i < folderModel.count; ++i) {
            next[String(folderModel.get(i, "fileUrl"))] = true;
        }
        selected = next;
    }
    function selectedUrls(): var {
        return Object.keys(selected);
    }
    function quickShare(): void {
        const urls = selectedUrls().filter(u => !Files.info(u).isDir);
        if (urls.length === 0) {
            app.showMessage(i18n("Only files can be sent. Compress a folder to ZIP first."), "", null);
            return;
        }
        Process.launchApplication("org.kernora.share", urls);
    }
    function isSelected(url: url): bool {
        return !!selected[String(url)];
    }

    function press(row: int, mouse: var): void {
        view.forceActiveFocus();
        view.currentIndex = row;
        const url = String(folderModel.get(row, "fileUrl"));
        if (mouse.button === Qt.RightButton) {
            if (!selected[url]) {
                selectOnly(row);
            }
            return;
        }
        if (mouse.modifiers & Qt.ControlModifier) {
            toggle(row);
        } else if (mouse.modifiers & Qt.ShiftModifier) {
            selectRange(row);
        } else {
            selectOnly(row);
        }
    }

    property var clipboard: ({ urls: [], cut: false })

    function report(ok: bool, message: string): void {
        if (!ok && message.length > 0) {
            showMessage(message, "", null);
        }
    }

    function open(row: int): void {
        const url = String(folderModel.get(row, "fileUrl"));
        if (folderModel.get(row, "fileIsDir")) {
            go(url);
        } else if (inTrash) {
            showMessage(i18n("Restore the file to open it."), i18n("Restore"), () => app.restore());
        } else if (Kinds.isArchive(url) && !url.endsWith(".deb") && !url.endsWith(".iso")) {
            extractDialog.url = url;
            extractDialog.open();
        } else {
            Process.openUrl(url);
        }
    }
    function openSelection(): void {
        const urls = selectedUrls();
        if (urls.length === 1 && Files.info(urls[0]).isDir) {
            go(urls[0]);
            return;
        }
        for (const url of urls) {
            Process.openUrl(url);
        }
    }
    function copy(cut: bool): void {
        const urls = selectedUrls();
        if (urls.length > 0) {
            clipboard = { urls: urls, cut: cut };
            showMessage(cut ? i18np("%1 item will be moved", "%1 items will be moved", urls.length)
                            : i18np("%1 item copied", "%1 items copied", urls.length), "", null);
        }
    }
    function paste(): void {
        if (clipboard.urls.length === 0 || inTrash) {
            return;
        }
        const urls = clipboard.urls;
        const cut = clipboard.cut;
        if (cut) {
            clipboard = { urls: [], cut: false };
        }
        const here = String(folder).replace(/\/$/, "");
        const sameFolder = urls.filter(u => String(u).replace(/\/[^\/]*\/?$/, "") === here);
        const clashes = Files.conflicts(urls, folder).filter(u => !sameFolder.some(s => String(s) === String(u)));
        if (sameFolder.length > 0) {
            if (cut) {
                app.report(true, "");
            } else {
                Files.transfer(sameFolder, folder, false, "rename", (ok, message) => app.report(ok, message));
            }
        }
        const others = urls.filter(u => !sameFolder.some(s => String(s) === String(u)));
        if (others.length === 0) {
            return;
        }
        if (clashes.length === 0) {
            Files.transfer(others, folder, cut, "", (ok, message) => app.report(ok, message));
            return;
        }
        conflictDialog.urls = others;
        conflictDialog.clashes = clashes;
        conflictDialog.cut = cut;
        conflictDialog.target = folder;
        conflictDialog.open();
    }

    function resolveConflict(choice: string): void {
        const urls = conflictDialog.urls;
        const clashes = conflictDialog.clashes.map(u => String(u));
        conflictDialog.close();
        const list = choice === "skip" ? urls.filter(u => !clashes.includes(String(u))) : urls;
        Files.transfer(list, conflictDialog.target, conflictDialog.cut, choice === "skip" ? "" : choice,
                       (ok, message) => app.report(ok, message));
    }
    function trash(): void {
        const urls = selectedUrls();
        if (urls.length === 0) {
            return;
        }
        if (inTrash) {
            deleteDialog.urls = urls;
            deleteDialog.open();
            return;
        }
        Files.trash(urls, (ok, message) => {
            if (ok) {
                app.showMessage(i18np("%1 item moved to the trash", "%1 items moved to the trash", urls.length), "", null);
            } else {
                app.report(ok, message);
            }
        });
        clearSelection();
    }
    function deleteForever(): void {
        const urls = selectedUrls();
        if (urls.length > 0) {
            deleteDialog.urls = urls;
            deleteDialog.open();
        }
    }
    function restore(): void {
        Files.restore(selectedUrls(), (ok, message) => {
            app.report(ok, message);
            if (ok) {
                app.showMessage(i18n("Restored"), "", null);
            }
        });
        clearSelection();
    }
    function rename(): void {
        const urls = selectedUrls();
        if (urls.length === 1) {
            renameDialog.url = urls[0];
            renameDialog.open();
        }
    }
    function compress(): void {
        Files.compress(selectedUrls(), (ok, message) => app.report(ok, message));
    }
    function extract(): void {
        for (const url of selectedUrls()) {
            Files.extract(url, (ok, message) => app.report(ok, message));
        }
    }

    Shortcut { sequences: [StandardKey.Back, "Alt+Left", "Backspace"]; onActivated: app.back() }
    Shortcut { sequences: [StandardKey.Forward, "Alt+Right"]; onActivated: app.forward() }
    Shortcut { sequence: "Alt+Up"; onActivated: app.up() }
    Shortcut { sequence: "Alt+Home"; onActivated: app.go(Files.standardFolder("home")) }
    Shortcut { sequence: "Ctrl+L"; onActivated: pathBar.edit() }
    Shortcut { sequences: [StandardKey.Find]; onActivated: { filterBox.shown = true; filter.forceActiveFocus(); } }
    Shortcut { sequence: "Ctrl+H"; onActivated: showHidden.value = !app.isOn(showHidden) }
    Shortcut { sequence: "Ctrl+Shift+N"; onActivated: newFolderDialog.open() }
    Shortcut { sequences: [StandardKey.SelectAll]; onActivated: app.selectAll() }
    Shortcut { sequences: [StandardKey.Copy]; onActivated: app.copy(false) }
    Shortcut { sequences: [StandardKey.Cut]; onActivated: app.copy(true) }
    Shortcut { sequences: [StandardKey.Paste]; onActivated: app.paste() }
    Shortcut { sequences: [StandardKey.Delete]; onActivated: app.trash() }
    Shortcut { sequence: "Shift+Del"; onActivated: app.deleteForever() }
    Shortcut { sequence: "F2"; onActivated: app.rename() }
    Shortcut { sequence: "F5"; onActivated: { const f = app.folder; folderModel.folder = ""; folderModel.folder = f; } }
    Shortcut { sequence: "Alt+Return"; onActivated: app.showProperties() }

    function showProperties(): void {
        const urls = selectedUrls();
        propertiesDialog.info = Files.info(urls.length > 0 ? urls[0] : folder);
        propertiesDialog.count = urls.length;
        propertiesDialog.open();
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Sidebar {
            id: sidebar
            Layout.fillHeight: true
            Layout.preferredWidth: 260
            Layout.topMargin: 8
            Layout.leftMargin: 8
            visible: !app.narrow
            currentFolder: app.folder
            onChosen: folder => app.go(folder)
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 12
                Layout.topMargin: 8
                Layout.bottomMargin: 8
                spacing: 4

                IconButton { iconName: "go-previous"; text: i18n("Back"); enabled: app.historyIndex > 0; onClicked: app.back() }
                IconButton { iconName: "go-next"; text: i18n("Forward"); enabled: app.historyIndex < app.history.length - 1; onClicked: app.forward() }
                IconButton { iconName: "go-up"; text: i18n("Up"); enabled: app.folderPath !== "/"; onClicked: app.up() }

                PathBar {
                    id: pathBar
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    folder: app.folder
                    homePath: app.homePath
                    trashPath: app.trashPath
                    onChosen: folder => app.go(folder)
                }

                IconButton {
                    iconName: "search"
                    text: i18n("Find in this folder")
                    checked: filterBox.shown
                    onClicked: {
                        filterBox.shown = !filterBox.shown;
                        if (filterBox.shown) {
                            filter.forceActiveFocus();
                        } else {
                            filter.text = "";
                        }
                    }
                }
                IconButton {
                    iconName: app.listMode ? "view-grid" : "view-list-details"
                    text: app.listMode ? i18n("Show as grid") : i18n("Show as list")
                    onClicked: viewMode.value = app.listMode ? "grid" : "list"
                }
                IconButton {
                    id: moreButton
                    iconName: "overflow-menu"
                    text: i18n("More")
                    onClicked: moreMenu.popup(moreButton, 0, moreButton.height)
                }
            }

            Rectangle {
                id: pane
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.rightMargin: app.narrow ? 0 : 12
                Layout.bottomMargin: app.narrow ? 0 : 12
                radius: app.narrow ? 0 : (M3.classic ? M3.cornerCard : 28)
                color: M3.surface

                ColumnLayout {
                    anchors.fill: parent
                    anchors.topMargin: 12
                    spacing: 0

                    Banner {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        Layout.bottomMargin: 8
                        visible: app.inTrash && folderModel.count > 0
                        tone: "neutral"
                        icon: "user-trash"
                        text: i18n("Files in the trash can be restored until the trash is emptied.")
                        actionText: i18n("Empty the trash")
                        onActionTriggered: emptyDialog.open()
                    }
                    Item {
                        id: filterBox
                        property bool shown: false
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        Layout.bottomMargin: 8
                        implicitHeight: shown ? filter.implicitHeight : 0
                        visible: shown
                        SearchField {
                            id: filter
                            width: parent.width
                            placeholderText: i18n("Find in “%1”", app.folderName)
                            Keys.onEscapePressed: {
                                text = "";
                                filterBox.shown = false;
                                view.forceActiveFocus();
                            }
                            Keys.onDownPressed: view.forceActiveFocus()
                        }
                    }

                    GridView {
                        id: view

                        readonly property int columns: app.listMode ? 1 : Math.max(1, Math.floor((width - 24) / 150))

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        leftMargin: app.listMode ? 12 : 12
                        rightMargin: 12
                        bottomMargin: 88
                        clip: true
                        focus: true
                        model: folderModel
                        cellWidth: app.listMode ? width - 24 : Math.floor((width - 24) / columns)
                        cellHeight: app.listMode ? 60 : cellWidth * 0.78 + 72
                        currentIndex: -1
                        keyNavigationEnabled: true
                        boundsBehavior: Flickable.StopAtBounds
                        QQC2.ScrollBar.vertical: QQC2.ScrollBar {}

                        delegate: FileItem {
                            id: item
                            width: view.cellWidth
                            height: view.cellHeight
                            list: app.listMode
                            selected: app.isSelected(fileUrl)
                            current: GridView.isCurrentItem
                            showFocus: view.activeFocus
                            cut: app.clipboard.cut && app.clipboard.urls.indexOf(String(fileUrl)) >= 0
                            details: fileIsDir ? Qt.formatDate(fileModified, Locale.ShortFormat)
                                : SystemInfo.formatBytes(fileSize) + " · " + Qt.formatDate(fileModified, Locale.ShortFormat)
                            onPressed: mouse => app.press(index, mouse)
                            onActivated: app.open(index)
                            onMenuRequested: (x, y) => (app.inTrash ? trashMenu : fileMenu).popup(item, x, y)
                        }

                        Keys.onReturnPressed: {
                            if (currentIndex >= 0) {
                                app.open(currentIndex);
                            }
                        }
                        Keys.onSpacePressed: {
                            if (currentIndex >= 0) {
                                app.toggle(currentIndex);
                            }
                        }
                        Keys.onMenuPressed: (app.inTrash ? trashMenu : fileMenu).popup()
                        onCurrentIndexChanged: {
                            if (activeFocus && currentIndex >= 0 && !app.isSelected(folderModel.get(currentIndex, "fileUrl"))) {
                                app.selectOnly(currentIndex);
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            z: -1
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onPressed: event => {
                                view.forceActiveFocus();
                                app.clearSelection();
                                if (event.button === Qt.RightButton) {
                                    folderMenu.popup();
                                }
                            }
                        }
                    }

                    MText {
                        Layout.fillWidth: true
                        Layout.leftMargin: 24
                        Layout.rightMargin: 24
                        Layout.bottomMargin: 12
                        Layout.topMargin: 4
                        role: "bodySmall"
                        color: M3.surfaceVariantContent
                        text: app.selectedCount > 0
                            ? i18np("%1 selected", "%1 selected", app.selectedCount) + " · " + i18np("%1 item", "%1 items", folderModel.count)
                            : i18np("%1 item", "%1 items", folderModel.count)
                    }
                }

                EmptyState {
                    anchors.centerIn: parent
                    width: parent.width - 48
                    visible: folderModel.status === FolderListModel.Ready && folderModel.count === 0
                    icon: app.inTrash ? "user-trash" : filter.text.length > 0 ? "search" : "folder"
                    title: app.inTrash ? i18n("The trash is empty") : filter.text.length > 0 ? i18n("Nothing found") : i18n("This folder is empty")
                    text: filter.text.length > 0 ? i18n("No names contain “%1”.", filter.text) : ""
                }

                Kirigami.ShadowedRectangle {
                    id: fab

                    property bool collapsed: false
                    property real lastY: 0
                    readonly property bool selecting: !M3.classic && app.selectedCount > 0
                    readonly property real extendedWidth: fabRow.implicitWidth + 36

                    Connections {
                        target: view
                        function onContentYChanged() {
                            const y = view.contentY - view.originY;
                            if (y <= 8 || y < fab.lastY - 4) {
                                fab.collapsed = false;
                            } else if (y > fab.lastY + 4) {
                                fab.collapsed = true;
                            }
                            fab.lastY = y;
                        }
                    }

                    MMorph {
                        id: expandMorph
                        active: !fab.collapsed || M3.classic
                        dampingRatio: M3.springExpressiveDefaultDamping
                        response: M3.springExpressiveDefaultResponse
                    }
                    MMorph { id: fabPress; active: fabMouse.pressed && !M3.classic }
                    MMorph {
                        id: fabShown
                        active: !app.inTrash && !fab.selecting
                        dampingRatio: M3.springExpressiveDefaultDamping
                        response: M3.springExpressiveDefaultResponse
                    }

                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 20
                    visible: fabShown.value > 0.01
                    opacity: Math.min(1, fabShown.value * 1.5)
                    scale: 0.6 + 0.4 * fabShown.value
                    transformOrigin: Item.BottomRight
                    width: 56 + (extendedWidth - 56) * Math.max(0, expandMorph.value)
                    height: 56
                    radius: M3.classic ? M3.cornerButton : 16 - 4 * fabPress.value
                    color: M3.primaryContainer
                    readonly property var elevation: M3.elevationOf("fab")
                    shadow.xOffset: 0
                    shadow.yOffset: elevation.offset
                    shadow.size: elevation.blur
                    shadow.color: Qt.rgba(0, 0, 0, M3.dark ? elevation.opacity + 0.2 : elevation.opacity)
                    Accessible.role: Accessible.Button
                    Accessible.name: i18n("New folder")
                    MStateLayer {
                        radius: fab.radius
                        color: M3.primaryContainerContent
                        hovered: fabMouse.containsMouse
                        pressed: fabMouse.pressed
                        pressPoint: Qt.point(fabMouse.mouseX, fabMouse.mouseY)
                    }
                    MIcon {
                        x: 16
                        anchors.verticalCenter: parent.verticalCenter
                        size: 24
                        source: "folder-new"
                        color: M3.primaryContainerContent
                    }
                    RowLayout {
                        id: fabRow
                        x: 16
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12
                        opacity: Math.max(0, Math.min(1, expandMorph.value * 1.4 - 0.4))
                        Item { implicitWidth: 24; implicitHeight: 24 }
                        MText { role: "labelLarge"; text: i18n("New folder"); color: M3.primaryContainerContent }
                    }
                    MouseArea {
                        id: fabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: newFolderDialog.open()
                        QQC2.ToolTip.text: i18n("New folder")
                        QQC2.ToolTip.visible: fab.collapsed && containsMouse
                        QQC2.ToolTip.delay: 600
                    }
                }

                FloatingToolbar {
                    id: selectionBar
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 20
                    vibrant: true
                    shown: fab.selecting

                    ToolbarButton {
                        iconName: "window-close"
                        text: i18n("Clear selection")
                        onClicked: app.clearSelection()
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: 24
                        color: M3.withAlpha(M3.primaryContainerContent, 0.3)
                    }
                    ToolbarButton {
                        visible: app.inTrash
                        iconName: "edit-undo"
                        text: i18n("Restore")
                        onClicked: app.restore()
                    }
                    ToolbarButton {
                        visible: !app.inTrash
                        iconName: "edit-cut"
                        text: i18n("Cut")
                        onClicked: app.copy(true)
                    }
                    ToolbarButton {
                        visible: !app.inTrash
                        iconName: "edit-copy"
                        text: i18n("Copy")
                        onClicked: app.copy(false)
                    }
                    ToolbarButton {
                        visible: !app.inTrash
                        iconName: "kernora-quickshare"
                        text: i18n("Send with Quick Share")
                        onClicked: app.quickShare()
                    }
                    ToolbarButton {
                        visible: !app.inTrash && app.selectedCount === 1
                        iconName: "edit-rename"
                        text: i18n("Rename")
                        onClicked: app.rename()
                    }
                    ToolbarButton {
                        iconName: "user-trash"
                        text: app.inTrash ? i18n("Delete forever") : i18n("Move to trash")
                        onClicked: app.inTrash ? app.deleteForever() : app.trash()
                    }
                    ToolbarButton {
                        id: selectionMore
                        iconName: "overflow-menu"
                        text: i18n("More")
                        onClicked: {
                            const menu = app.inTrash ? trashMenu : fileMenu;
                            menu.popup(selectionMore, 0, 0);
                            menu.y = Qt.binding(() => -menu.height - 16);
                        }
                    }
                }
            }
        }
    }

    component ToolbarButton: IconButton {
        implicitWidth: 48
        implicitHeight: 48
        ink: selectionBar.ink
        checkedFill: selectionBar.checkedFill
        checkedInk: selectionBar.checkedInk
    }

    QQC2.Menu {
        id: fileMenu

        readonly property var urls: app.selectedUrls()
        readonly property var first: urls.length === 1 ? Files.info(urls[0]) : ({})
        readonly property bool single: urls.length === 1

        QQC2.MenuItem { text: i18n("Open"); icon.name: "document-open"; onTriggered: app.openSelection() }
        QQC2.Menu {
            id: openWith
            title: i18n("Open with")
            enabled: fileMenu.single && !fileMenu.first.isDir
            Instantiator {
                model: openWith.enabled && fileMenu.visible ? DefaultApps.applicationsFor(fileMenu.urls[0]) : []
                delegate: QQC2.MenuItem {
                    required property var modelData
                    text: modelData.name
                    icon.name: modelData.icon
                    onTriggered: Process.launchApplication(modelData.storageId, [fileMenu.urls[0]])
                }
                onObjectAdded: (index, object) => openWith.insertItem(index, object)
                onObjectRemoved: (index, object) => openWith.removeItem(object)
            }
        }
        QQC2.MenuItem { text: i18n("Send with Quick Share"); icon.name: "kernora-quickshare"; onTriggered: app.quickShare() }
        QQC2.MenuSeparator {}
        QQC2.MenuItem { text: i18n("Cut"); icon.name: "edit-cut"; onTriggered: app.copy(true) }
        QQC2.MenuItem { text: i18n("Copy"); icon.name: "edit-copy"; onTriggered: app.copy(false) }
        QQC2.MenuItem { text: i18n("Rename"); icon.name: "edit-rename"; enabled: fileMenu.single; onTriggered: app.rename() }
        QQC2.MenuItem { text: i18n("Compress to ZIP"); icon.name: "application-x-archive"; onTriggered: app.compress() }
        QQC2.MenuItem {
            text: i18n("Extract here")
            icon.name: "application-x-archive"
            visible: fileMenu.urls.some(u => Kinds.isArchive(u))
            onTriggered: app.extract()
        }
        QQC2.MenuItem {
            text: i18n("Set as wallpaper")
            icon.name: "preferences-desktop-wallpaper"
            visible: fileMenu.single && Kinds.hasThumbnail(fileMenu.urls[0] || "")
            onTriggered: {
                Files.setWallpaper(fileMenu.urls[0]);
                app.showMessage(i18n("Wallpaper changed"), "", null);
            }
        }
        QQC2.MenuSeparator {}
        QQC2.MenuItem { text: i18n("Move to trash"); icon.name: "user-trash"; onTriggered: app.trash() }
        QQC2.MenuItem { text: i18n("Delete forever"); icon.name: "user-trash"; onTriggered: app.deleteForever() }
        QQC2.MenuSeparator {}
        QQC2.MenuItem { text: i18n("Properties"); icon.name: "document-properties"; onTriggered: app.showProperties() }
    }

    QQC2.Menu {
        id: trashMenu
        QQC2.MenuItem { text: i18n("Restore"); icon.name: "edit-undo"; onTriggered: app.restore() }
        QQC2.MenuItem { text: i18n("Delete forever"); icon.name: "user-trash"; onTriggered: app.deleteForever() }
        QQC2.MenuSeparator {}
        QQC2.MenuItem { text: i18n("Properties"); icon.name: "document-properties"; onTriggered: app.showProperties() }
    }

    QQC2.Menu {
        id: folderMenu
        QQC2.MenuItem { text: i18n("New folder"); icon.name: "folder-new"; enabled: !app.inTrash; onTriggered: newFolderDialog.open() }
        QQC2.MenuItem {
            text: i18n("Paste")
            icon.name: "edit-paste"
            enabled: app.clipboard.urls.length > 0 && !app.inTrash
            onTriggered: app.paste()
        }
        QQC2.MenuItem { text: i18n("Select all"); icon.name: "edit-select-all"; onTriggered: app.selectAll() }
        QQC2.MenuSeparator {}
        QQC2.MenuItem { text: i18n("Open terminal here"); icon.name: "utilities-terminal"; visible: !app.inTrash; onTriggered: Process.startDetached("alacritty", ["--class", "org.kernora.terminal", "--working-directory", app.folderPath]) }
        QQC2.MenuItem { text: i18n("Empty the trash"); icon.name: "trash-empty"; visible: app.inTrash; onTriggered: emptyDialog.open() }
        QQC2.MenuItem { text: i18n("Properties"); icon.name: "document-properties"; onTriggered: { app.clearSelection(); app.showProperties(); } }
    }

    QQC2.Menu {
        id: moreMenu
        QQC2.MenuItem { text: i18n("New folder"); icon.name: "folder-new"; enabled: !app.inTrash; onTriggered: newFolderDialog.open() }
        QQC2.MenuItem { text: i18n("Paste"); icon.name: "edit-paste"; enabled: app.clipboard.urls.length > 0 && !app.inTrash; onTriggered: app.paste() }
        QQC2.MenuSeparator {}
        QQC2.Menu {
            title: i18n("Sort by")
            QQC2.MenuItem { text: i18n("Name"); checkable: true; checked: Number(sortField.value) === FolderListModel.Name; onTriggered: sortField.value = FolderListModel.Name }
            QQC2.MenuItem { text: i18n("Date modified"); checkable: true; checked: Number(sortField.value) === FolderListModel.Time; onTriggered: sortField.value = FolderListModel.Time }
            QQC2.MenuItem { text: i18n("Size"); checkable: true; checked: Number(sortField.value) === FolderListModel.Size; onTriggered: sortField.value = FolderListModel.Size }
            QQC2.MenuItem { text: i18n("Type"); checkable: true; checked: Number(sortField.value) === FolderListModel.Type; onTriggered: sortField.value = FolderListModel.Type }
            QQC2.MenuSeparator {}
            QQC2.MenuItem { text: i18n("Reverse order"); checkable: true; checked: app.isOn(sortReversed); onTriggered: sortReversed.value = !app.isOn(sortReversed) }
        }
        QQC2.MenuItem { text: i18n("Show hidden files"); checkable: true; checked: app.isOn(showHidden); onTriggered: showHidden.value = !app.isOn(showHidden) }
        QQC2.MenuSeparator {}
        QQC2.Menu {
            title: i18n("Places")
            visible: app.narrow
            enabled: app.narrow
            QQC2.MenuItem { text: i18n("Home"); icon.name: "user-home"; onTriggered: app.go(Files.standardFolder("home")) }
            QQC2.MenuItem { text: i18n("Documents"); icon.name: "folder-documents"; onTriggered: app.go(Files.standardFolder("documents")) }
            QQC2.MenuItem { text: i18n("Downloads"); icon.name: "folder-download"; onTriggered: app.go(Files.standardFolder("downloads")) }
            QQC2.MenuItem { text: i18n("Pictures"); icon.name: "folder-pictures"; onTriggered: app.go(Files.standardFolder("pictures")) }
            QQC2.MenuItem { text: i18n("Trash"); icon.name: "user-trash"; onTriggered: app.go(Files.trashFolder()) }
        }
        QQC2.MenuItem { text: i18n("Open terminal here"); icon.name: "utilities-terminal"; onTriggered: Process.startDetached("alacritty", ["--class", "org.kernora.terminal", "--working-directory", app.folderPath]) }
    }

    Dialog {
        id: newFolderDialog
        icon: "folder-new"
        title: i18n("New folder")
        acceptText: i18n("Create")
        acceptEnabled: newFolderName.text.trim().length > 0
        onOpened: {
            newFolderName.text = i18n("New folder");
            newFolderName.forceActiveFocus();
            newFolderName.input.selectAll();
        }
        onAccepted: Files.createFolder(app.folder, newFolderName.text, (ok, message) => app.report(ok, message))
        InputField {
            id: newFolderName
            Layout.fillWidth: true
            label: i18n("Name")
            onAccepted: {
                if (newFolderDialog.acceptEnabled) {
                    newFolderDialog.accept();
                }
            }
        }
    }

    Dialog {
        id: renameDialog
        property string url
        icon: "edit-rename"
        title: i18n("Rename")
        acceptText: i18n("Rename")
        acceptEnabled: newName.text.trim().length > 0 && !newName.text.includes("/")
        onOpened: {
            const name = Files.info(url).name;
            newName.text = name;
            newName.forceActiveFocus();
            const dot = name.lastIndexOf(".");
            newName.input.select(0, dot > 0 && !Files.info(url).isDir ? dot : name.length);
        }
        onAccepted: Files.rename(url, newName.text, (ok, message) => app.report(ok, message))
        InputField {
            id: newName
            Layout.fillWidth: true
            label: i18n("New name")
            errorText: newName.text.includes("/") ? i18n("A name cannot contain “/”.") : ""
            onAccepted: {
                if (renameDialog.acceptEnabled) {
                    renameDialog.accept();
                }
            }
        }
    }

    Dialog {
        id: deleteDialog
        property var urls: []
        icon: "user-trash"
        title: i18np("Delete %1 item forever?", "Delete %1 items forever?", urls.length)
        text: i18n("This cannot be undone.")
        acceptText: i18n("Delete")
        destructive: true
        onAccepted: {
            Files.remove(urls, (ok, message) => app.report(ok, message));
            app.clearSelection();
        }
    }

    Dialog {
        id: extractDialog
        property string url
        icon: "application-x-archive"
        title: i18n("Extract “%1”?", decodeURIComponent(url.split("/").pop()))
        text: i18n("The contents go into a new folder next to the archive.")
        acceptText: i18n("Extract")
        onAccepted: Files.extract(url, (ok, message) => {
            if (ok) {
                app.go("file://" + message.split("/").map(encodeURIComponent).join("/"));
            } else {
                app.report(ok, message);
            }
        })
    }

    Dialog {
        id: conflictDialog

        property var urls: []
        property var clashes: []
        property bool cut: false
        property url target

        icon: "edit-copy"
        title: clashes.length === 1 ? i18n("“%1” is already here", decodeURIComponent(String(clashes[0]).replace(/^.*\//, "")))
                                    : i18np("%1 item is already here", "%1 items are already here", clashes.length)
        text: i18n("Choose what to do with the files that have the same names.")
        showAccept: false

        ListItem {
            Layout.fillWidth: true
            title: i18n("Replace")
            subtitle: i18n("The files here are overwritten")
            icon: "kernora-install-replace"
            iconStyle: "plain"
            onClicked: app.resolveConflict("replace")
        }
        ListItem {
            Layout.fillWidth: true
            title: i18n("Keep both")
            subtitle: i18n("The new files get a number in their name")
            icon: "edit-copy"
            iconStyle: "plain"
            onClicked: app.resolveConflict("rename")
        }
        ListItem {
            Layout.fillWidth: true
            title: i18n("Skip")
            subtitle: conflictDialog.urls.length > conflictDialog.clashes.length ? i18n("Only the other files are copied") : i18n("Nothing is copied")
            icon: "media-skip-forward"
            iconStyle: "plain"
            onClicked: app.resolveConflict("skip")
        }
    }

    Dialog {
        id: emptyDialog
        icon: "trash-empty"
        title: i18n("Empty the trash?")
        text: i18n("Everything in the trash is deleted forever.")
        acceptText: i18n("Empty")
        destructive: true
        onAccepted: Files.emptyTrash((ok, message) => {
            if (ok) {
                trashEmptied.sendEvent();
            }
            app.report(ok, message);
        })
    }

    Notification {
        id: trashEmptied
        componentName: "plasma_workspace"
        eventId: "Trash: emptied"
        title: i18n("Trash emptied")
        iconName: "user-trash"
    }

    Dialog {
        id: propertiesDialog
        property var info: ({})
        property int count: 0
        readonly property var trashInfo: app.inTrash && count === 1 ? Files.trashInfo(info.path ? "file://" + info.path : "") : ({})

        icon: info.isDir ? "folder" : Kinds.iconOf(Kinds.kindOf(info.name || "", false))
        title: count > 1 ? i18np("%1 item", "%1 items", count) : (info.name || "")
        showReject: false
        acceptText: i18n("Close")
        preferredWidth: 460

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 20
            rowSpacing: 10

            MText { role: "labelLarge"; color: M3.surfaceVariantContent; text: i18n("Type") }
            MText { Layout.fillWidth: true; role: "bodyMedium"; text: propertiesDialog.info.isDir ? i18n("Folder") : (propertiesDialog.info.typeName || ""); wrapMode: Text.Wrap }
            MText { role: "labelLarge"; color: M3.surfaceVariantContent; text: i18n("Size"); visible: !propertiesDialog.info.isDir }
            MText { Layout.fillWidth: true; role: "bodyMedium"; visible: !propertiesDialog.info.isDir; text: propertiesDialog.info.sizeText || "" }
            MText { role: "labelLarge"; color: M3.surfaceVariantContent; text: i18n("Location") }
            MText { Layout.fillWidth: true; role: "bodyMedium"; text: decodeURIComponent(String(propertiesDialog.info.folder || "").replace(/^file:\/\//, "")); wrapMode: Text.WrapAnywhere }
            MText { role: "labelLarge"; color: M3.surfaceVariantContent; text: i18n("Modified") }
            MText { Layout.fillWidth: true; role: "bodyMedium"; text: propertiesDialog.info.modified ? propertiesDialog.info.modified.toLocaleString(Qt.locale(), Locale.ShortFormat) : "" }
            MText { role: "labelLarge"; color: M3.surfaceVariantContent; text: i18n("From"); visible: !!propertiesDialog.trashInfo.originalFolder }
            MText { Layout.fillWidth: true; role: "bodyMedium"; visible: !!propertiesDialog.trashInfo.originalFolder; text: propertiesDialog.trashInfo.originalFolder || ""; wrapMode: Text.WrapAnywhere }
        }
    }
}
