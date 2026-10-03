/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import org.kernora.m3
import org.kernora.ui

FocusScope {
    id: root

    property string query
    property var entries: []
    signal activated(var entry)

    function normalise(text: string): string {
        return text.toLocaleLowerCase().replace(/ё/g, "е").trim();
    }

    readonly property var matches: {
        const words = normalise(query).split(/\s+/).filter(w => w.length > 0);
        if (words.length === 0) {
            return [];
        }
        const scored = [];
        for (const entry of entries) {
            const title = normalise(entry.title);
            const rest = normalise(entry.section + " " + entry.keywords);
            let score = 0;
            let all = true;
            for (const word of words) {
                if (title.startsWith(word)) {
                    score += 4;
                } else if (title.includes(" " + word) || title.includes(word)) {
                    score += 3;
                } else if (rest.includes(word)) {
                    score += 1;
                } else {
                    all = false;
                    break;
                }
            }
            if (all) {
                scored.push({ entry: entry, score: score - (entry.section.length === 0 ? 0 : 0.5) });
            }
        }
        scored.sort((a, b) => b.score - a.score || a.entry.title.localeCompare(b.entry.title));
        return scored.map(s => s.entry);
    }

    function activateFirst(): void {
        if (matches.length > 0) {
            activated(matches[0]);
        }
    }

    ListView {
        id: list
        anchors.fill: parent
        focus: true
        clip: true
        spacing: 2
        model: root.matches
        keyNavigationEnabled: true
        QQC2.ScrollBar.vertical: QQC2.ScrollBar {}

        delegate: NavigationItem {
            required property var modelData
            required property int index
            width: ListView.view.width
            title: modelData.title
            subtitle: modelData.section.length > 0 ? modelData.section : i18n("Section")
            icon: modelData.icon
            accent: modelData.accent
            current: ListView.isCurrentItem && list.activeFocus
            onClicked: root.activated(modelData)
            Keys.onReturnPressed: root.activated(modelData)
        }
        Keys.onReturnPressed: {
            if (currentIndex >= 0) {
                root.activated(root.matches[currentIndex]);
            }
        }
    }

    EmptyState {
        anchors.centerIn: parent
        width: parent.width - 32
        visible: root.matches.length === 0
        icon: "search"
        title: i18n("Nothing found")
        text: i18n("Try another word, like “Wi-Fi”, “wallpaper” or “password”.")
    }
}
