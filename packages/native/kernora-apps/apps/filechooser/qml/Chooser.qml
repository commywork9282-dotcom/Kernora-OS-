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
import "../files"
import "../files/kinds.js" as Kinds

AppWindow {
    id: chooser

    property string mode: "open"
    property string heading
    property string acceptLabel
    property bool multiple: false
    property bool directory: false
    property var filters: []
    property int currentFilter: -1
    property var choices: []
    property url startFolder
    property bool folderGiven: false
    property string startName
    property var fileNames: []

    signal finished(var result)

    readonly property bool saving: mode === "save"
    readonly property bool choosingFolder: directory || mode === "saveFiles"

    title: heading.length > 0 ? heading.replace(/\s*[:：]\s*$/, "")
        : mode === "save" ? i18n("Save As")
        : choosingFolder ? i18n("Choose a Folder")
        : multiple ? i18n("Open Files") : i18n("Open a File")
    width: 1000
    height: 680
    minimumWidth: 520
    minimumHeight: 440
    color: M3.surfaceContainer
    flags: Qt.Dialog
    visible: false

    readonly property bool narrow: width < 760
    readonly property string homePath: String(Files.standardFolder("home")).replace(/^file:\/\//, "")

    property bool answered: false
    function answer(result: var): void {
        if (answered) {
            return;
        }
        answered = true;
        if (result.accepted) {
            lastFolder.value = String(folder);
        }
        result.filter = currentFilter;
        result.choices = choices.map(c => ({ id: c.id, value: chosen[c.id] !== undefined ? chosen[c.id] : c.selected }));
        finished(result);
    }
    function cancel(): void {
        answer({ accepted: false });
    }
    onClosing: cancel()

    property var chosen: ({})
    function choose(id: string, value: string): void {
        const next = Object.assign({}, chosen);
        next[id] = value;
        chosen = next;
    }
    function choiceValue(choice: var): string {
        return chosen[choice.id] !== undefined ? chosen[choice.id] : choice.selected;
    }

    readonly property string acceptText: acceptLabel.length > 0 ? acceptLabel.replace(/_/g, "")
        : saving || mode === "saveFiles" ? i18n("Save")
        : choosingFolder ? i18n("Choose")
        : i18n("Open")

    function accept(): void {
        if (mode === "saveFiles") {
            const urls = selectedUrls();
            const target = urls.length === 1 && Files.info(urls[0]).isDir ? urls[0] : String(folder);
            const base = String(target).replace(/\/$/, "");
            answer({ accepted: true, uris: fileNames.map(name => base + "/" + encodeURIComponent(name)) });
        } else if (saving) {
            save();
        } else {
            open();
        }
    }

    function open(): void {
        let urls = selectedUrls();
        if (directory) {
            if (urls.length === 0) {
                urls = [String(folder)];
            }
            answer({ accepted: true, uris: urls });
            return;
        }
        if (urls.length === 1 && Files.info(urls[0]).isDir) {
            go(urls[0]);
            return;
        }
        urls = urls.filter(url => !Files.info(url).isDir);
        if (urls.length > 0) {
            answer({ accepted: true, uris: urls });
        }
    }

    function save(): void {
        let name = nameField.text.trim();
        if (name.length === 0) {
            return;
        }
        if (name.startsWith("~/")) {
            name = homePath + name.slice(1);
        }
        const target = name.startsWith("/") ? toUrl(name)
            : String(folder).replace(/\/$/, "") + "/" + name.split("/").map(encodeURIComponent).join("/");
        const info = Files.info(target);
        if (info.isDir) {
            go(target);
            nameField.text = startName.split("/").pop();
            return;
        }
        if (info.exists) {
            replaceDialog.target = target;
            replaceDialog.name = info.name;
            replaceDialog.open();
            return;
        }
        answer({ accepted: true, uris: [target] });
    }

    function useFilter(index: int): void {
        currentFilter = index;
        if (!saving) {
            return;
        }
        const globs = filters[index] ? filters[index].globs : [];
        const match = globs.length > 0 ? /^\*\.([^*?\[\]/]+)$/.exec(globs[0]) : null;
        const name = nameField.text;
        if (!match || name.length === 0) {
            return;
        }
        const dot = name.lastIndexOf(".");
        nameField.text = (dot > 0 ? name.slice(0, dot) : name) + "." + match[1];
    }

    ConfigEntry { id: lastFolder; file: "kernora-filesrc"; group: "Chooser"; key: "LastFolder"; defaultValue: "" }
    function firstFolder(): string {
        if (folderGiven) {
            return String(startFolder);
        }
        const globs = filters[currentFilter] ? filters[currentFilter].globs : [];
        const kinds = [...new Set(globs.map(glob => Kinds.kindOf("file" + glob.replace(/^\*/, ""), false)))];
        if (kinds.length === 1) {
            const standard = { image: "pictures", audio: "music", video: "videos" }[kinds[0]];
            if (standard) {
                return String(Files.standardFolder(standard));
            }
        }
        const last = String(lastFolder.value);
        if (last.length > 0 && Files.info(last).isDir) {
            return last;
        }
        return String(startFolder);
    }

    property url folder
    readonly property string folderPath: decodeURIComponent(String(folder).replace(/^file:\/\//, "")).replace(/\/$/, "") || "/"
    property var history: []
    property int historyIndex: -1

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
        search.text = "";
        view.currentIndex = -1;
    }
    function back(): void {
        if (historyIndex > 0) {
            historyIndex -= 1;
            setFolder(history[historyIndex]);
        }
    }
    function up(): void {
        if (folderPath !== "/") {
            go(toUrl(folderPath.slice(0, folderPath.lastIndexOf("/")) || "/"));
        }
    }

    Component.onCompleted: {
        folder = firstFolder();
        history = [String(folder)];
        historyIndex = 0;
        nameField.text = startName;
        const dot = startName.lastIndexOf(".");
        nameField.input.select(0, dot > 0 ? dot : startName.length);
        if (saving) {
            nameField.forceActiveFocus();
        } else {
            view.forceActiveFocus();
        }
    }

    ConfigEntry { id: viewMode; file: "kernora-filesrc"; group: "View"; key: "Mode"; defaultValue: "grid" }
    ConfigEntry { id: sortField; file: "kernora-filesrc"; group: "View"; key: "Sort"; defaultValue: 1 }
    ConfigEntry { id: sortReversed; file: "kernora-filesrc"; group: "View"; key: "Reversed"; defaultValue: false }
    ConfigEntry { id: showHidden; file: "kernora-filesrc"; group: "View"; key: "ShowHidden"; defaultValue: false }
    readonly property bool listMode: viewMode.value === "list"
    function isOn(entry: var): bool {
        return entry.value === true || entry.value === "true";
    }

    readonly property var filterGlobs: filters[currentFilter] ? filters[currentFilter].globs : []

    FolderListModel {
        id: folderModel
        folder: chooser.folder
        showDirsFirst: true
        showFiles: !chooser.choosingFolder
        showHidden: chooser.isOn(showHidden)
        showDotAndDotDot: false
        caseSensitive: false
        sortCaseSensitive: false
        sortField: Number(sortField.value)
        sortReversed: chooser.isOn(sortReversed)
        nameFilters: search.text.trim().length > 0 ? ["*" + search.text.trim() + "*"] : chooser.filterGlobs
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
        if (saving && !folderModel.get(row, "fileIsDir")) {
            nameField.text = folderModel.get(row, "fileName");
        }
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
            if (!folderModel.get(i, "fileIsDir")) {
                next[String(folderModel.get(i, "fileUrl"))] = true;
            }
        }
        selected = next;
    }
    function selectedUrls(): var {
        return Object.keys(selected);
    }
    function isSelected(url: url): bool {
        return !!selected[String(url)];
    }

    function press(row: int, mouse: var): void {
        view.forceActiveFocus();
        view.currentIndex = row;
        if (multiple && (mouse.modifiers & Qt.ControlModifier)) {
            toggle(row);
        } else if (multiple && (mouse.modifiers & Qt.ShiftModifier)) {
            selectRange(row);
        } else {
            selectOnly(row);
        }
    }
    function activate(row: int): void {
        const url = folderModel.get(row, "fileUrl");
        if (folderModel.get(row, "fileIsDir")) {
            go(url);
        } else {
            selectOnly(row);
            accept();
        }
    }

    readonly property bool canAccept: {
        if (choosingFolder) {
            return true;
        }
        if (saving) {
            return nameText.length > 0;
        }
        return selectedCount > 0;
    }
    property string nameText: ""

    Shortcut { sequences: [StandardKey.Back, "Alt+Left"]; onActivated: chooser.back() }
    Shortcut { sequence: "Alt+Up"; onActivated: chooser.up() }
    Shortcut { sequence: "Alt+Home"; onActivated: chooser.go(Files.standardFolder("home")) }
    Shortcut { sequence: "Ctrl+L"; onActivated: pathBar.edit() }
    Shortcut { sequences: [StandardKey.Find]; onActivated: { searchBox.shown = true; search.forceActiveFocus(); } }
    Shortcut { sequence: "Ctrl+H"; onActivated: showHidden.value = !chooser.isOn(showHidden) }
    Shortcut { sequences: [StandardKey.SelectAll]; enabled: chooser.multiple && !nameField.input.activeFocus && !search.input.activeFocus; onActivated: chooser.selectAll() }
    Shortcut {
        sequence: "Escape"
        enabled: !replaceDialog.visible && !newFolderDialog.visible
        onActivated: {
            if (searchBox.shown) {
                search.text = "";
                searchBox.shown = false;
                view.forceActiveFocus();
            } else {
                chooser.cancel();
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Sidebar {
            Layout.fillHeight: true
            Layout.preferredWidth: 240
            Layout.topMargin: 8
            Layout.leftMargin: 8
            Layout.bottomMargin: 8
            visible: !chooser.narrow
            showTrash: false
            currentFolder: chooser.folder
            onChosen: folder => chooser.go(folder)
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 12
                Layout.topMargin: 12
                spacing: 4

                MText {
                    Layout.fillWidth: true
                    role: "headlineSmall"
                    text: chooser.title
                    elide: Text.ElideRight
                }
                IconButton {
                    iconName: "search"
                    text: i18n("Find in this folder")
                    checked: searchBox.shown
                    onClicked: {
                        searchBox.shown = !searchBox.shown;
                        if (searchBox.shown) {
                            search.forceActiveFocus();
                        } else {
                            search.text = "";
                        }
                    }
                }
                IconButton {
                    iconName: chooser.listMode ? "view-grid" : "view-list-details"
                    text: chooser.listMode ? i18n("Show as grid") : i18n("Show as list")
                    onClicked: viewMode.value = chooser.listMode ? "grid" : "list"
                }
                IconButton {
                    visible: chooser.saving || chooser.choosingFolder
                    iconName: "folder-new"
                    text: i18n("New folder")
                    onClicked: newFolderDialog.open()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 12
                Layout.topMargin: 8
                Layout.bottomMargin: 8
                spacing: 4

                IconButton { iconName: "go-previous"; text: i18n("Back"); enabled: chooser.historyIndex > 0; onClicked: chooser.back() }
                IconButton { iconName: "go-up"; text: i18n("Up"); enabled: chooser.folderPath !== "/"; onClicked: chooser.up() }
                PathBar {
                    id: pathBar
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    folder: chooser.folder
                    homePath: chooser.homePath
                    onChosen: folder => chooser.go(folder)
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.rightMargin: chooser.narrow ? 0 : 12
                radius: chooser.narrow ? 0 : (M3.classic ? M3.cornerCard : 28)
                color: M3.surface

                ColumnLayout {
                    anchors.fill: parent
                    anchors.topMargin: 12
                    spacing: 0

                    Item {
                        id: searchBox
                        property bool shown: false
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        Layout.bottomMargin: 8
                        implicitHeight: shown ? search.implicitHeight : 0
                        visible: shown
                        SearchField {
                            id: search
                            width: parent.width
                            placeholderText: i18n("Find in “%1”", chooser.folderPath === chooser.homePath ? i18n("Home") : (chooser.folderPath.split("/").pop() || i18n("Computer")))
                            Keys.onEscapePressed: event => {
                                text = "";
                                searchBox.shown = false;
                                view.forceActiveFocus();
                                event.accepted = true;
                            }
                            Keys.onDownPressed: view.forceActiveFocus()
                        }
                    }

                    GridView {
                        id: view

                        readonly property int columns: chooser.listMode ? 1 : Math.max(1, Math.floor((width - 24) / 150))

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        leftMargin: 12
                        rightMargin: 12
                        bottomMargin: 12
                        clip: true
                        focus: true
                        model: folderModel
                        cellWidth: chooser.listMode ? width - 24 : Math.floor((width - 24) / columns)
                        cellHeight: chooser.listMode ? 60 : cellWidth * 0.78 + 72
                        currentIndex: -1
                        keyNavigationEnabled: true
                        boundsBehavior: Flickable.StopAtBounds
                        QQC2.ScrollBar.vertical: QQC2.ScrollBar {}

                        delegate: FileItem {
                            id: item
                            width: view.cellWidth
                            height: view.cellHeight
                            list: chooser.listMode
                            selected: chooser.isSelected(fileUrl)
                            current: GridView.isCurrentItem
                            showFocus: view.activeFocus
                            details: fileIsDir ? Qt.formatDate(fileModified, Locale.ShortFormat)
                                : SystemInfo.formatBytes(fileSize) + " · " + Qt.formatDate(fileModified, Locale.ShortFormat)
                            onPressed: mouse => chooser.press(index, mouse)
                            onActivated: chooser.activate(index)
                        }

                        Keys.onReturnPressed: {
                            if (currentIndex >= 0) {
                                chooser.activate(currentIndex);
                            } else if (chooser.canAccept) {
                                chooser.accept();
                            }
                        }
                        Keys.onSpacePressed: {
                            if (currentIndex >= 0) {
                                chooser.multiple ? chooser.toggle(currentIndex) : chooser.selectOnly(currentIndex);
                            }
                        }
                        onCurrentIndexChanged: {
                            if (activeFocus && currentIndex >= 0 && !chooser.isSelected(folderModel.get(currentIndex, "fileUrl"))) {
                                chooser.selectOnly(currentIndex);
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            z: -1
                            onPressed: {
                                view.forceActiveFocus();
                                chooser.clearSelection();
                            }
                        }
                    }
                }

                EmptyState {
                    anchors.centerIn: parent
                    width: parent.width - 48
                    visible: folderModel.status === FolderListModel.Ready && folderModel.count === 0
                    icon: search.text.length > 0 ? "search" : "folder"
                    title: search.text.length > 0 ? i18n("Nothing found")
                        : chooser.choosingFolder ? i18n("No folders here")
                        : chooser.filterGlobs.length > 0 ? i18n("No suitable files here")
                        : i18n("This folder is empty")
                    text: search.text.length > 0 ? i18n("No names contain “%1”.", search.text) : ""
                }
            }

            InputField {
                id: nameField
                Layout.fillWidth: true
                Layout.leftMargin: chooser.narrow ? 12 : 0
                Layout.rightMargin: 12
                Layout.topMargin: 12
                visible: chooser.saving
                label: i18n("Name")
                onTextChanged: chooser.nameText = text.trim()
                onAccepted: chooser.accept()
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: chooser.narrow ? 12 : 0
                Layout.rightMargin: 12
                Layout.topMargin: 12
                Layout.bottomMargin: 12
                spacing: 8

                Flow {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 8

                    DropChip {
                        visible: chooser.filters.length > 1
                        icon: "view-filter"
                        text: chooser.filters[chooser.currentFilter] ? chooser.filters[chooser.currentFilter].name : ""
                        options: chooser.filters.map((filter, index) => ({ value: index, label: filter.name }))
                        currentValue: chooser.currentFilter
                        onSelected: value => chooser.useFilter(value)
                    }

                    Repeater {
                        model: chooser.choices
                        delegate: Loader {
                            id: choiceLoader
                            required property var modelData
                            sourceComponent: modelData.options.length > 0 ? listChoice : switchChoice

                            Component {
                                id: listChoice
                                DropChip {
                                    readonly property var option: choiceLoader.modelData.options.find(o => o.value === chooser.choiceValue(choiceLoader.modelData))
                                    text: choiceLoader.modelData.label + ": " + (option ? option.label : "")
                                    options: choiceLoader.modelData.options
                                    currentValue: chooser.choiceValue(choiceLoader.modelData)
                                    onSelected: value => chooser.choose(choiceLoader.modelData.id, value)
                                }
                            }
                            Component {
                                id: switchChoice
                                ToggleChip {
                                    text: choiceLoader.modelData.label
                                    checked: chooser.choiceValue(choiceLoader.modelData) === "true"
                                    onToggled: on => chooser.choose(choiceLoader.modelData.id, on ? "true" : "false")
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignBottom
                    spacing: 8
                    MText {
                        visible: chooser.multiple && chooser.selectedCount > 1
                        Layout.rightMargin: 8
                        role: "bodyMedium"
                        color: M3.surfaceVariantContent
                        text: i18np("%1 selected", "%1 selected", chooser.selectedCount)
                    }
                    MButton {
                        variant: "text"
                        text: i18n("Cancel")
                        onClicked: chooser.cancel()
                    }
                    MButton {
                        variant: "filled"
                        text: chooser.acceptText
                        enabled: chooser.canAccept
                        onClicked: chooser.accept()
                    }
                }
            }
        }
    }

    component DropChip: Rectangle {
        id: chip
        property string icon
        property string text
        property var options: []
        property var currentValue
        signal selected(var value)

        implicitWidth: chipRow.implicitWidth + 28
        implicitHeight: 40
        radius: M3.classic ? M3.cornerButton : 8
        color: chipMouse.containsMouse ? M3.withAlpha(M3.surfaceContent, 0.08) : "transparent"
        border.width: 1
        border.color: M3.outlineVariant

        RowLayout {
            id: chipRow
            anchors.centerIn: parent
            spacing: 8
            MIcon {
                visible: chip.icon.length > 0
                size: 18
                source: chip.icon
                color: M3.primary
            }
            MText {
                role: "labelLarge"
                text: chip.text
                Layout.maximumWidth: 320
                elide: Text.ElideRight
            }
            MIcon {
                size: 18
                source: "arrow-down"
                color: M3.surfaceVariantContent
            }
        }
        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chipMenu.popup(chip, 0, chip.height + 4)
        }
        QQC2.Menu {
            id: chipMenu
            Repeater {
                model: chip.options
                delegate: QQC2.MenuItem {
                    required property var modelData
                    text: modelData.label
                    checkable: true
                    checked: modelData.value === chip.currentValue
                    onTriggered: chip.selected(modelData.value)
                }
            }
        }
    }

    component ToggleChip: Rectangle {
        id: toggle
        property string text
        property bool checked: false
        signal toggled(bool on)

        implicitWidth: toggleRow.implicitWidth + 28
        implicitHeight: 40
        radius: M3.classic ? M3.cornerButton : 8
        color: checked ? M3.secondaryContainer : (toggleMouse.containsMouse ? M3.withAlpha(M3.surfaceContent, 0.08) : "transparent")
        border.width: checked ? 0 : 1
        border.color: M3.outlineVariant

        RowLayout {
            id: toggleRow
            anchors.centerIn: parent
            spacing: 8
            MIcon {
                visible: toggle.checked
                size: 18
                source: "checkmark"
                color: M3.secondaryContainerContent
            }
            MText {
                role: "labelLarge"
                text: toggle.text
                color: toggle.checked ? M3.secondaryContainerContent : M3.surfaceVariantContent
            }
        }
        MouseArea {
            id: toggleMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: toggle.toggled(!toggle.checked)
        }
    }

    Dialog {
        id: replaceDialog
        property string target
        property string name
        icon: "dialog-warning"
        title: i18n("Replace “%1”?", name)
        text: i18n("A file with this name already exists in this folder. Saving replaces its contents.")
        acceptText: i18n("Replace")
        destructive: true
        onAccepted: chooser.answer({ accepted: true, uris: [target] })
    }

    Dialog {
        id: newFolderDialog
        title: i18n("New folder")
        acceptText: i18n("Create")
        acceptEnabled: folderName.text.trim().length > 0
        onAboutToShow: {
            folderName.text = i18n("New folder");
            folderName.input.selectAll();
            folderName.forceActiveFocus();
        }
        onAccepted: Files.createFolder(chooser.folder, folderName.text.trim(), (ok, message) => {
            if (ok) {
                chooser.go(String(chooser.folder).replace(/\/$/, "") + "/" + encodeURIComponent(folderName.text.trim()));
            } else {
                chooser.showMessage(message, "", null);
            }
        })

        InputField {
            id: folderName
            Layout.fillWidth: true
            label: i18n("Name")
            onAccepted: newFolderDialog.accept()
        }
    }
}
