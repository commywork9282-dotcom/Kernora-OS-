/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kernora.m3
import org.kernora.ui

ColumnLayout {
    id: root

    property TextEdit editor
    property bool replacing: false
    property bool matchCase: false

    visible: false
    spacing: 8

    function show(replace: bool): void {
        replacing = replace;
        visible = true;
        const selected = editor.selectedText;
        if (selected.length > 0 && !selected.includes("\n")) {
            field.text = selected;
        }
        field.forceActiveFocus();
        field.input.selectAll();
    }
    function hide(): void {
        visible = false;
        editor.forceActiveFocus();
    }

    function normalise(text: string): string {
        return matchCase ? text : text.toLocaleLowerCase();
    }

    readonly property int count: {
        const needle = normalise(field.text);
        if (needle.length === 0 || !visible) {
            return 0;
        }
        const haystack = normalise(editor.text);
        let n = 0;
        for (let i = haystack.indexOf(needle); i >= 0; i = haystack.indexOf(needle, i + needle.length)) {
            ++n;
        }
        return n;
    }

    function find(forward: bool): bool {
        const needle = normalise(field.text);
        if (needle.length === 0) {
            return false;
        }
        const haystack = normalise(editor.text);
        let at;
        if (forward) {
            at = haystack.indexOf(needle, editor.selectionEnd);
            if (at < 0) {
                at = haystack.indexOf(needle);
            }
        } else {
            at = haystack.lastIndexOf(needle, Math.max(0, editor.selectionStart - 1));
            if (at < 0 || at >= editor.selectionStart) {
                at = haystack.lastIndexOf(needle);
            }
        }
        if (at < 0) {
            return false;
        }
        editor.select(at, at + needle.length);
        return true;
    }
    function replaceOne(): void {
        if (editor.selectedText.length > 0 && normalise(editor.selectedText) === normalise(field.text)) {
            editor.remove(editor.selectionStart, editor.selectionEnd);
            editor.insert(editor.cursorPosition, replacement.text);
        }
        find(true);
    }
    function replaceAll(): void {
        const needle = field.text;
        if (needle.length === 0) {
            return;
        }
        const flags = matchCase ? "g" : "gi";
        const pattern = new RegExp(needle.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), flags);
        const position = editor.cursorPosition;
        const replaced = editor.text.replace(pattern, () => replacement.text);
        editor.remove(0, editor.length);
        editor.insert(0, replaced);
        editor.cursorPosition = Math.min(position, editor.length);
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        SearchField {
            id: field
            Layout.fillWidth: true
            placeholderText: i18n("Find")
            onTextChanged: {
                if (text.length > 0) {
                    root.editor.cursorPosition = root.editor.selectionStart;
                    root.find(true);
                }
            }
            onAccepted: root.find(true)
            Keys.onEscapePressed: root.hide()
            Keys.onPressed: event => {
                if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.ShiftModifier)) {
                    root.find(false);
                    event.accepted = true;
                }
            }
        }
        MText {
            role: "labelMedium"
            color: M3.surfaceVariantContent
            text: field.text.length > 0 ? i18np("%1 match", "%1 matches", root.count) : ""
        }
        IconButton { iconName: "go-up"; text: i18n("Previous"); onClicked: root.find(false) }
        IconButton { iconName: "go-down"; text: i18n("Next"); onClicked: root.find(true) }
        IconButton {
            iconName: "kernora-match-case"
            text: i18n("Match case")
            checked: root.matchCase
            onClicked: root.matchCase = !root.matchCase
        }
        IconButton { iconName: "edit-find-replace"; text: i18n("Replace"); checked: root.replacing; onClicked: root.replacing = !root.replacing }
        IconButton { iconName: "window-close"; text: i18n("Close"); onClicked: root.hide() }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: root.replacing
        spacing: 8

        SearchField {
            id: replacement
            Layout.fillWidth: true
            placeholderText: i18n("Replace with")
            onAccepted: root.replaceOne()
            Keys.onEscapePressed: root.hide()
        }
        QQC2.Button { text: i18n("Replace"); onClicked: root.replaceOne() }
        QQC2.Button { text: i18n("Replace all"); onClicked: root.replaceAll() }
    }
}
