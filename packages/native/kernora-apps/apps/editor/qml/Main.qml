/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Dialogs as Dialogs
import org.kde.syntaxhighlighting
import org.kernora.m3
import org.kernora.ui
import org.kernora.system

AppWindow {
    id: app

    width: 980
    height: 720
    minimumWidth: 420
    minimumHeight: 360
    color: M3.surfaceContainer
    visible: true
    title: (modified ? "● " : "") + documentName

    property url fileUrl
    readonly property bool modified: editor.textDocument.modified
    readonly property string documentName: String(fileUrl).length > 0 ? decodeURIComponent(String(fileUrl).split("/").pop()) : i18n("Untitled")
    readonly property string documentFolder: String(fileUrl).length > 0 ? decodeURIComponent(String(fileUrl).replace(/^file:\/\//, "").replace(/\/[^/]*$/, "")) : ""

    ConfigEntry { id: wrap; file: "kernora-editorrc"; group: "View"; key: "WordWrap"; defaultValue: true }
    ConfigEntry { id: numbers; file: "kernora-editorrc"; group: "View"; key: "LineNumbers"; defaultValue: true }
    ConfigEntry { id: fontSize; file: "kernora-editorrc"; group: "View"; key: "FontSize"; defaultValue: 11 }
    function isOn(entry: var): bool {
        return entry.value === true || entry.value === "true";
    }

    function load(url: string): bool {
        const result = Files.readText(url);
        if (!result.ok) {
            showMessage(result.error || i18n("The file could not be opened."), "", null);
            return false;
        }
        editor.text = result.text;
        fileUrl = url;
        editor.textDocument.modified = false;
        editor.cursorPosition = 0;
        highlighter.definition = Repository.definitionForFileName(documentName);
        return true;
    }

    function save(then: var): void {
        if (String(fileUrl).length === 0) {
            saveDialog.then = then || null;
            saveDialog.open();
            return;
        }
        if (Files.writeText(fileUrl, editor.text)) {
            editor.textDocument.modified = false;
            if (then) {
                then();
            }
        } else {
            showMessage(i18n("The file could not be saved. You may not have permission to write there."), i18n("Save as…"), () => {
                saveDialog.then = then || null;
                saveDialog.open();
            });
        }
    }

    function guard(action: var): void {
        if (!modified) {
            action();
            return;
        }
        unsavedDialog.action = action;
        unsavedDialog.open();
    }

    function handleArguments(args: var): void {
        for (const argument of args || []) {
            const url = String(argument);
            if (url.startsWith("file:")) {
                if (!Files.exists(url)) {
                    fileUrl = url;
                    editor.text = "";
                    editor.textDocument.modified = false;
                } else {
                    load(url);
                }
                return;
            }
        }
    }
    Component.onCompleted: {
        handleArguments(startArguments);
        editor.forceActiveFocus();
    }

    property bool closing: false
    onClosing: close => {
        if (modified && !closing) {
            close.accepted = false;
            guard(() => {
                app.closing = true;
                app.close();
            });
        }
    }

    Shortcut { sequences: [StandardKey.New]; onActivated: Process.startDetached("kernora-editor", []) }
    Shortcut { sequences: [StandardKey.Open]; onActivated: app.guard(() => openDialog.open()) }
    Shortcut { sequences: [StandardKey.Save]; onActivated: app.save(null) }
    Shortcut { sequences: [StandardKey.SaveAs]; onActivated: { saveDialog.then = null; saveDialog.open(); } }
    Shortcut { sequences: [StandardKey.Find]; onActivated: findBar.show(false) }
    Shortcut { sequences: [StandardKey.Replace, "Ctrl+H"]; onActivated: findBar.show(true) }
    Shortcut { sequences: [StandardKey.FindNext, "F3"]; onActivated: findBar.find(true) }
    Shortcut { sequences: [StandardKey.FindPrevious, "Shift+F3"]; onActivated: findBar.find(false) }
    Shortcut { sequences: [StandardKey.ZoomIn, "Ctrl+="]; onActivated: fontSize.value = Math.min(40, Number(fontSize.value) + 1) }
    Shortcut { sequences: [StandardKey.ZoomOut]; onActivated: fontSize.value = Math.max(7, Number(fontSize.value) - 1) }
    Shortcut { sequence: "Ctrl+0"; onActivated: fontSize.value = 11 }
    Shortcut { sequence: "Ctrl+G"; onActivated: gotoDialog.open() }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 8
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            spacing: 4

            IconButton { iconName: "document-new"; text: i18n("New window"); onClicked: Process.startDetached("kernora-editor", []) }
            IconButton { iconName: "document-open"; text: i18n("Open"); onClicked: app.guard(() => openDialog.open()) }
            IconButton { iconName: "document-save"; text: i18n("Save"); enabled: app.modified || String(app.fileUrl).length === 0; onClicked: app.save(null) }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 12
                spacing: 0
                MText {
                    Layout.fillWidth: true
                    role: "titleMedium"
                    text: app.documentName
                }
                MText {
                    Layout.fillWidth: true
                    role: "bodySmall"
                    color: M3.surfaceVariantContent
                    text: app.modified ? i18n("Edited") : app.documentFolder
                    elide: Text.ElideMiddle
                }
            }

            IconButton { iconName: "edit-undo"; text: i18n("Undo"); enabled: editor.canUndo; onClicked: editor.undo() }
            IconButton { iconName: "edit-redo"; text: i18n("Redo"); enabled: editor.canRedo; onClicked: editor.redo() }
            IconButton { iconName: "search"; text: i18n("Find and replace"); onClicked: findBar.show(true) }
            IconButton {
                id: moreButton
                iconName: "overflow-menu"
                text: i18n("More")
                onClicked: moreMenu.popup(moreButton, 0, moreButton.height)
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            Layout.bottomMargin: 12
            radius: M3.classic ? M3.cornerCard : 28
            color: M3.surface
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 8
                spacing: 0

                FindBar {
                    id: findBar
                    Layout.fillWidth: true
                    Layout.leftMargin: 12
                    Layout.rightMargin: 12
                    editor: editor
                }

                    Flickable {
                        id: flick
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentWidth: app.isOn(wrap) ? width : editor.x + editor.width + 16
                        contentHeight: editor.y + editor.height + 16
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true
                        QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
                        QQC2.ScrollBar.horizontal: QQC2.ScrollBar { visible: !app.isOn(wrap) }

                        function ensureVisible(rect: rect): void {
                            if (contentY >= rect.y) {
                                contentY = rect.y;
                            } else if (contentY + height <= rect.y + rect.height + 12) {
                                contentY = rect.y + rect.height + 12 - height;
                            }
                            if (contentX >= rect.x + gutter.width) {
                                contentX = Math.max(0, rect.x + gutter.width - 20);
                            } else if (contentX + width <= rect.x + gutter.width + 20) {
                                contentX = rect.x + gutter.width + 20 - width;
                            }
                        }

                        Column {
                            id: gutter
                            x: 0
                            y: editor.y + editor.topPadding
                            width: visible ? Math.max(3, String(editor.lineCount).length) * editorMetrics.averageCharacterWidth + 28 : 0
                            visible: app.isOn(numbers) && !app.isOn(wrap)
                            Repeater {
                                model: gutter.visible ? editor.lineCount : 0
                                delegate: Text {
                                    required property int index
                                    width: gutter.width - 12
                                    height: editor.lineCount > 0 ? editor.contentHeight / editor.lineCount : 0
                                    horizontalAlignment: Text.AlignRight
                                    verticalAlignment: Text.AlignVCenter
                                    font: editor.font
                                    color: M3.withAlpha(M3.surfaceVariantContent, 0.6)
                                    text: index + 1
                                }
                            }
                        }

                        TextEdit {
                            id: editor
                            x: gutter.width + (gutter.visible ? 4 : 12)
                            y: 4
                            width: app.isOn(wrap) ? flick.width - x - 16 : Math.max(implicitWidth, flick.width - x - 16)
                            topPadding: 8
                            bottomPadding: 8
                            leftPadding: 8
                            rightPadding: 8
                            focus: true
                            selectByMouse: true
                            persistentSelection: true
                            wrapMode: app.isOn(wrap) ? TextEdit.Wrap : TextEdit.NoWrap
                            textFormat: TextEdit.PlainText
                            tabStopDistance: editorMetrics.averageCharacterWidth * 4
                            font.family: "Hack"
                            font.pointSize: Number(fontSize.value)
                            color: M3.surfaceContent
                            selectionColor: M3.primaryContainer
                            selectedTextColor: M3.primaryContainerContent
                            onCursorRectangleChanged: flick.ensureVisible(cursorRectangle)
                        }

                        FontMetrics {
                            id: editorMetrics
                            font: editor.font
                        }
                    }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 24
                    Layout.rightMargin: 24
                    Layout.topMargin: 4
                    Layout.bottomMargin: 10
                    spacing: 16

                    readonly property int line: editor.text.slice(0, editor.cursorPosition).split("\n").length
                    readonly property int column: editor.cursorPosition - editor.text.lastIndexOf("\n", editor.cursorPosition - 1)

                    MText {
                        role: "bodySmall"
                        color: M3.surfaceVariantContent
                        text: i18n("Line %1, column %2", parent.line, parent.column)
                    }
                    MText {
                        role: "bodySmall"
                        color: M3.surfaceVariantContent
                        text: highlighter.definition && highlighter.definition.name !== "None" ? highlighter.definition.translatedName : i18n("Plain text")
                    }
                    Item { Layout.fillWidth: true }
                    MText {
                        role: "bodySmall"
                        color: M3.surfaceVariantContent
                        text: i18np("%1 line", "%1 lines", editor.lineCount) + " · UTF-8"
                    }
                }
            }
        }
    }

    SyntaxHighlighter {
        id: highlighter
        textEdit: editor
        theme: Repository.defaultTheme(M3.dark ? Repository.DarkTheme : Repository.LightTheme)
    }

    QQC2.Menu {
        id: moreMenu
        QQC2.MenuItem { text: i18n("Save as…"); icon.name: "document-save-as"; onTriggered: { saveDialog.then = null; saveDialog.open(); } }
        QQC2.MenuItem {
            text: i18n("Show in Files")
            icon.name: "system-file-manager"
            enabled: String(app.fileUrl).length > 0 && Files.exists(app.fileUrl)
            onTriggered: Process.launchApplication("org.kernora.files.desktop", [app.fileUrl])
        }
        QQC2.MenuSeparator {}
        QQC2.MenuItem { text: i18n("Wrap long lines"); checkable: true; checked: app.isOn(wrap); onTriggered: wrap.value = !app.isOn(wrap) }
        QQC2.MenuItem { text: i18n("Line numbers"); checkable: true; checked: app.isOn(numbers); enabled: !app.isOn(wrap); onTriggered: numbers.value = !app.isOn(numbers) }
        QQC2.MenuItem { text: i18n("Go to line…"); onTriggered: gotoDialog.open() }
        QQC2.Menu {
            id: highlightingMenu
            title: i18n("Highlighting")
            QQC2.MenuItem { text: i18n("Plain text"); onTriggered: highlighter.definition = Repository.definitionForName("None") }
            Instantiator {
                model: ["Bash", "C++", "CSS", "HTML", "INI Files", "JavaScript", "JSON", "Markdown", "Python", "QML", "Rust", "XML", "YAML"]
                delegate: QQC2.MenuItem {
                    required property string modelData
                    text: modelData
                    onTriggered: highlighter.definition = Repository.definitionForName(modelData)
                }
                onObjectAdded: (index, object) => highlightingMenu.insertItem(index + 1, object)
                onObjectRemoved: (index, object) => highlightingMenu.removeItem(object)
            }
        }
        QQC2.MenuSeparator {}
        QQC2.MenuItem { text: i18n("Bigger text"); icon.name: "zoom-in"; onTriggered: fontSize.value = Math.min(40, Number(fontSize.value) + 1) }
        QQC2.MenuItem { text: i18n("Smaller text"); icon.name: "zoom-out"; onTriggered: fontSize.value = Math.max(7, Number(fontSize.value) - 1) }
    }

    Dialogs.FileDialog {
        id: openDialog
        title: i18n("Open a text file")
        currentFolder: app.documentFolder.length > 0 ? "file://" + app.documentFolder : Files.standardFolder("documents")
        onAccepted: app.load(selectedFile)
    }

    Dialogs.FileDialog {
        id: saveDialog
        property var then: null
        title: i18n("Save as")
        fileMode: Dialogs.FileDialog.SaveFile
        currentFolder: app.documentFolder.length > 0 ? "file://" + app.documentFolder : Files.standardFolder("documents")
        selectedFile: String(app.fileUrl).length > 0 ? app.fileUrl : currentFolder + "/" + i18n("Untitled") + ".txt"
        onAccepted: {
            app.fileUrl = selectedFile;
            highlighter.definition = Repository.definitionForFileName(app.documentName);
            app.save(then);
        }
    }

    Dialog {
        id: unsavedDialog
        property var action: null
        icon: "document-save"
        title: i18n("Save changes to “%1”?", app.documentName)
        text: i18n("Your changes are lost if you don't save them.")
        acceptText: i18n("Save")
        rejectText: i18n("Cancel")
        onAccepted: app.save(action)

        QQC2.Button {
            Layout.alignment: Qt.AlignRight
            text: i18n("Don't save")
            flat: true
            onClicked: {
                const action = unsavedDialog.action;
                unsavedDialog.close();
                editor.textDocument.modified = false;
                if (action) {
                    action();
                }
            }
        }
    }

    Dialog {
        id: gotoDialog
        title: i18n("Go to line")
        acceptText: i18n("Go")
        acceptEnabled: parseInt(lineField.text) > 0
        onOpened: {
            lineField.text = "";
            lineField.forceActiveFocus();
        }
        onAccepted: {
            const line = Math.min(parseInt(lineField.text), editor.lineCount);
            let position = 0;
            for (let i = 1; i < line; ++i) {
                position = editor.text.indexOf("\n", position) + 1;
            }
            editor.cursorPosition = position;
            editor.forceActiveFocus();
        }
        InputField {
            id: lineField
            Layout.fillWidth: true
            label: i18n("Line (1–%1)", editor.lineCount)
            input.validator: IntValidator { bottom: 1 }
            onAccepted: {
                if (gotoDialog.acceptEnabled) {
                    gotoDialog.accept();
                }
            }
        }
    }
}
