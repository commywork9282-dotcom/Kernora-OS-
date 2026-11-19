/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import io.calamares.core 1.0
import io.calamares.ui 1.0

import QtQuick
import QtQuick.Controls
import org.kernora.m3
import org.kernora.ui
import "keymaps.js" as Keymaps

PixelPage {
    id: summary

    icon: "check_circle"
    title: qsTr("Ready to install")
    description: qsTr("Check that everything is right. When you press Install, the disk will be changed.")
    primaryAction: () => confirm.open()

    property string language: Qt.locale().name.split("_")[0]

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

    ListView {
        id: list

        anchors.fill: parent
        spacing: 2
        clip: true
        model: config.summaryModel
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}

        delegate: Rectangle {
            id: card

            required property int index
            required property string title
            required property string message
            readonly property bool first: index === 0
            readonly property bool last: index === list.count - 1
            readonly property string symbolName: ["language", "keyboard", "hard_drive", "person", "settings"][Math.min(index, 4)]

            width: list.width
            implicitHeight: row.implicitHeight + 36
            color: M3.surfaceContainerHigh
            topLeftRadius: first ? 24 : 6
            topRightRadius: first ? 24 : 6
            bottomLeftRadius: last ? 24 : 6
            bottomRightRadius: last ? 24 : 6

            Row {
                id: row

                x: 20
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 40
                spacing: 16

                MIcon {
                    size: 24
                    source: summary.symbol(card.symbolName)
                    color: M3.primary
                }

                Column {
                    width: parent.width - 40
                    spacing: 4

                    MText {
                        width: parent.width
                        role: "titleMedium"
                        text: card.title
                        wrapMode: Text.Wrap
                    }

                    Text {
                        width: parent.width
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

    Dialog {
        id: confirm
        title: qsTr("Start installing?")
        text: qsTr("The changes to the disk can't be undone.")
        acceptText: summary.plain(ViewManager.nextLabel)
        rejectText: qsTr("Cancel")
        destructive: true
        onAccepted: {
            close();
            ViewManager.next();
        }
    }

    function onActivate() {
        language = Qt.locale().name.split("_")[0];
    }

    function onLeave() {}
}
