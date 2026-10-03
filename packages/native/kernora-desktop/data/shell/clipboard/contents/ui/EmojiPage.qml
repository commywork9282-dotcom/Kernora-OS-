/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import "m3"
import "emoji.js" as EmojiData

Item {
    id: root

    property string query: ""
    property var recent: []

    signal chosen(string emoji)

    readonly property bool russian: Qt.locale().name.startsWith("ru")
    readonly property int columns: Math.max(1, Math.floor(width / 40))
    readonly property real cellWidth: width / columns
    readonly property int cell: 40

    property var hovered: null
    property string currentGroup: ""

    readonly property var categories: [
        { id: "recent", icon: "view-history", title: i18n("Recently used") },
        { id: "smileys", icon: "kernora-emoji-smileys", title: i18n("Smileys and emotion") },
        { id: "people", icon: "kernora-emoji-people", title: i18n("People and body") },
        { id: "nature", icon: "kernora-emoji-nature", title: i18n("Animals and nature") },
        { id: "food", icon: "kernora-emoji-food", title: i18n("Food and drink") },
        { id: "travel", icon: "kernora-emoji-travel", title: i18n("Travel and places") },
        { id: "activities", icon: "kernora-emoji-activities", title: i18n("Activities") },
        { id: "objects", icon: "kernora-emoji-objects", title: i18n("Objects") },
        { id: "symbols", icon: "kernora-emoji-symbols", title: i18n("Symbols") },
        { id: "flags", icon: "kernora-emoji-flags", title: i18n("Flags") }
    ]

    function titleOf(id: string): string {
        const category = categories.find(c => c.id === id);
        return category ? category.title : "";
    }

    function nameOf(entry: var): string {
        return root.russian && entry[2] ? entry[2] : entry[1];
    }

    function glyphOf(entry: var): string {
        return entry[4] ?? entry[0];
    }

    readonly property var byText: {
        const map = {};
        for (const group of EmojiData.groups) {
            for (const entry of group.emoji) {
                map[entry[0]] = entry;
            }
        }
        return map;
    }

    readonly property var rows: {
        const rows = [];
        const perRow = root.columns;
        function add(group, title, entries) {
            if (entries.length === 0) {
                return;
            }
            if (title.length > 0) {
                rows.push({ group: group, header: title });
            }
            for (let i = 0; i < entries.length; i += perRow) {
                rows.push({ group: group, cells: entries.slice(i, i + perRow) });
            }
        }
        const words = root.query.trim().toLowerCase().split(/\s+/).filter(word => word.length > 0);
        if (words.length > 0) {
            const found = [];
            for (const group of EmojiData.groups) {
                for (const entry of group.emoji) {
                    if (words.every(word => entry[3].includes(word))) {
                        found.push(entry);
                    }
                }
            }
            add("search", "", found);
            return rows;
        }
        add("recent", titleOf("recent"), root.recent.map(text => root.byText[text]).filter(entry => entry !== undefined));
        for (const group of EmojiData.groups) {
            add(group.id, titleOf(group.id), group.emoji);
        }
        return rows;
    }

    readonly property var firstMatch: {
        for (const row of rows) {
            if (row.cells) {
                return row.cells[0];
            }
        }
        return null;
    }

    function jumpTo(group: string): void {
        const row = rows.findIndex(r => r.group === group);
        if (row >= 0) {
            list.positionViewAtIndex(row, ListView.Beginning);
            root.currentGroup = group;
        }
    }

    function reset(): void {
        list.positionViewAtBeginning();
        root.hovered = null;
        root.currentGroup = rows.length > 0 ? rows[0].group : "";
    }

    onRowsChanged: list.positionViewAtBeginning()
    Component.onCompleted: reset()

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 0
            visible: root.query.trim().length === 0

            Repeater {
                model: root.categories.filter(c => c.id !== "recent" || root.recent.length > 0)

                delegate: Item {
                    id: tab
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 40

                    MIconButton {
                        anchors.centerIn: parent
                        size: 36
                        iconSize: 20
                        icon: tab.modelData.icon
                        text: tab.modelData.title
                        variant: root.currentGroup === tab.modelData.id ? "tonal" : "standard"
                        onClicked: root.jumpTo(tab.modelData.id)
                    }
                }
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.rows
            boundsBehavior: Flickable.StopAtBounds
            reuseItems: true

            onContentYChanged: {
                const row = indexAt(0, contentY + 2);
                if (row >= 0 && row < root.rows.length) {
                    root.currentGroup = root.rows[row].group;
                }
            }

            delegate: Item {
                id: rowItem
                required property var modelData
                width: ListView.view.width
                height: modelData.header !== undefined ? 36 : root.cell

                MText {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6
                    visible: rowItem.modelData.header !== undefined
                    role: "labelLarge"
                    color: M3.surfaceVariantContent
                    text: rowItem.modelData.header ?? ""
                }

                Row {
                    visible: rowItem.modelData.cells !== undefined

                    Repeater {
                        model: rowItem.modelData.cells ?? []

                        delegate: Item {
                            id: emojiCell
                            required property var modelData
                            width: root.cellWidth
                            height: root.cell

                            Accessible.role: Accessible.Button
                            Accessible.name: root.nameOf(modelData)

                            Item {
                                anchors.centerIn: parent
                                width: root.cell - 2
                                height: root.cell - 2

                                MStateLayer {
                                    radius: width / 2
                                    color: M3.surfaceContent
                                    hovered: mouse.containsMouse
                                    pressed: mouse.pressed
                                    pressPoint: Qt.point(mouse.mouseX, mouse.mouseY)
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: root.glyphOf(emojiCell.modelData)
                                font.family: "Noto Color Emoji"
                                font.pixelSize: 26
                                renderType: Text.NativeRendering
                            }

                            MouseArea {
                                id: mouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onContainsMouseChanged: {
                                    if (containsMouse) {
                                        root.hovered = emojiCell.modelData;
                                    }
                                }
                                onClicked: root.chosen(emojiCell.modelData[0])
                            }
                        }
                    }
                }
            }

            MScrollIndicator {
                flickable: list
                visible: scrollable
            }
        }

        MText {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            role: "bodyMedium"
            color: M3.surfaceVariantContent
            visible: root.rows.length === 0
            horizontalAlignment: Text.AlignHCenter
            text: i18n("No emoji match your search")
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.preferredHeight: 28
            spacing: 8
            opacity: root.hovered ? 1 : 0

            Text {
                text: root.hovered ? root.glyphOf(root.hovered) : ""
                font.family: "Noto Color Emoji"
                font.pixelSize: 18
                renderType: Text.NativeRendering
            }
            MText {
                Layout.fillWidth: true
                role: "bodyMedium"
                color: M3.surfaceVariantContent
                text: root.hovered ? root.nameOf(root.hovered) : ""
            }
        }
    }
}
