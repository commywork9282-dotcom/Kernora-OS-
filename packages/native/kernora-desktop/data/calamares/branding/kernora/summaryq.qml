/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import io.calamares.core 1.0
import io.calamares.ui 1.0

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kernora.m3
import org.kernora.ui
import "keymaps.js" as Keymaps

Item {
    id: summary

    property string language: Qt.locale().name.split("_")[0]
    function onActivate() {
        language = Qt.locale().name.split("_")[0];
    }

    function localized(title: string, message: string): string {
        const table = Keymaps.names[language];
        if (!table || title !== qsTranslate("KeyboardQmlViewStep", "Keyboard", "@label")) {
            return message;
        }
        const isWord = c => /[A-Za-z0-9]/.test(c);
        let result = message;
        for (const english of Object.keys(table).sort((a, b) => b.length - a.length)) {
            let at = result.indexOf(english);
            while (at >= 0) {
                const end = at + english.length;
                if (!isWord(result.charAt(at - 1)) && !isWord(result.charAt(end))) {
                    result = result.slice(0, at) + table[english] + result.slice(end);
                    at = result.indexOf(english, at + table[english].length);
                } else {
                    at = result.indexOf(english, at + 1);
                }
            }
        }
        return result;
    }

    Rectangle {
        anchors.fill: parent
        color: M3.surface
    }

    ListView {
        id: list
        anchors.fill: parent
        anchors.leftMargin: 40
        anchors.rightMargin: 40
        topMargin: 32
        bottomMargin: 24
        spacing: 2
        clip: true
        model: config.summaryModel
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}

        header: MText {
            width: list.width
            bottomPadding: 20
            role: "headlineSmall"
            text: config.message
            wrapMode: Text.Wrap
        }

        delegate: Rectangle {
            id: card
            required property int index
            required property string title
            required property string message
            readonly property bool first: index === 0
            readonly property bool last: index === list.count - 1

            width: list.width
            implicitHeight: row.implicitHeight + 32
            color: M3.surfaceContainer
            topLeftRadius: first ? 20 : 4
            topRightRadius: first ? 20 : 4
            bottomLeftRadius: last ? 20 : 4
            bottomRightRadius: last ? 20 : 4

            RowLayout {
                id: row
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 16

                IconCircle {
                    Layout.alignment: Qt.AlignTop
                    accent: [3, 2, 1, 0, 5][card.index % 5]
                    icon: ["preferences-desktop-locale", "input-keyboard", "drive-harddisk", "user-identity", "configure"][Math.min(card.index, 4)]
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    MText {
                        Layout.fillWidth: true
                        role: "titleMedium"
                        text: card.title
                        wrapMode: Text.Wrap
                    }
                    Text {
                        Layout.fillWidth: true
                        text: summary.localized(card.title, card.message)
                        textFormat: Text.StyledText
                        wrapMode: Text.Wrap
                        font: M3.bodyMedium
                        color: M3.surfaceVariantContent
                        linkColor: M3.primary
                    }
                }
            }
        }
    }

    function onLeave() {}
}
