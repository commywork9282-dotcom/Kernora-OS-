/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtCore
import QtQuick
import QtQuick.Layouts
import org.kde.kitemmodels as KItemModels
import org.kernora.ui as UI
import "m3"

FocusScope {
    id: root

    required property QtObject history
    property int maximumHeight: 560
    property string page: "clipboard"

    signal requestClose()

    width: 420
    height: Math.min(implicitHeight, maximumHeight)
    implicitHeight: column.implicitHeight

    function reset(startPage: string): void {
        openedAt = Date.now();
        page = startPage === "emoji" ? "emoji" : "clipboard";
        search.clear();
        list.currentIndex = 0;
        list.positionViewAtBeginning();
        loadRecentEmoji();
        if (emojiLoader.item) {
            emojiLoader.item.reset();
        }
        search.input.forceActiveFocus();
    }

    function choose(uuid: string): void {
        root.history.moveToTop(uuid);
        root.requestClose();
    }

    function chooseCurrent(): void {
        if (page === "emoji") {
            const entry = emojiLoader.item ? emojiLoader.item.firstMatch : null;
            if (entry) {
                chooseEmoji(entry[0]);
            }
            return;
        }
        const item = list.currentItem ?? list.itemAtIndex(0);
        if (item) {
            choose(item.uuid);
        }
    }

    function chooseEmoji(emoji: string): void {
        copier.text = emoji;
        copier.selectAll();
        copier.copy();
        const recent = [emoji].concat(recentEmoji.filter(other => other !== emoji)).slice(0, 30);
        recentEmoji = recent;
        recentStore.setValue("recent", recent.join(" "));
        recentStore.sync();
        root.requestClose();
    }

    property var recentEmoji: []
    Settings {
        id: recentStore
        location: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/kernora-emojirc"
        category: "Emoji"
    }
    function loadRecentEmoji(): void {
        recentStore.sync();
        const stored = recentStore.value("recent", "");
        recentEmoji = typeof stored === "string" ? stored.split(" ").filter(emoji => emoji.length > 0) : [];
    }

    TextEdit {
        id: copier
        visible: false
    }

    Keys.onEscapePressed: root.requestClose()

    property double openedAt: 0
    Keys.onPressed: event => {
        const modifierOnly = event.key === Qt.Key_Meta || event.key === Qt.Key_Super_L
            || event.key === Qt.Key_Super_R;
        if ((event.modifiers & Qt.MetaModifier) && !modifierOnly && !event.isAutoRepeat
                && Date.now() - root.openedAt > 400) {
            root.requestClose();
            event.accepted = true;
        }
    }

    KItemModels.KSortFilterProxyModel {
        id: filtered
        sourceModel: root.history
        filterRoleName: "display"
        filterString: root.page === "clipboard" ? search.text : ""
        filterCaseSensitivity: Qt.CaseInsensitive
    }

    ColumnLayout {
        id: column
        anchors.fill: parent
        spacing: 0

        UI.SegmentedButtons {
            Layout.fillWidth: true
            Layout.topMargin: 4
            options: [
                { value: "clipboard", label: i18n("Clipboard"), icon: "edit-paste" },
                { value: "emoji", label: i18n("Emoji"), icon: "kernora-emoji-smileys" }
            ]
            currentValue: root.page
            onSelected: value => {
                root.page = value;
                search.clear();
                search.input.forceActiveFocus();
            }
        }

        MText {
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            Layout.topMargin: 12
            role: "bodyMedium"
            color: M3.surfaceVariantContent
            wrapMode: Text.Wrap
            text: root.page === "emoji"
                ? i18n("Choose an emoji, then paste it with Ctrl+V")
                : i18n("Choose an item, then paste it with Ctrl+V")
            visible: root.page === "emoji" || root.history.count > 0
        }

        MSearchBar {
            id: search
            Layout.fillWidth: true
            Layout.topMargin: 12
            Layout.preferredHeight: 48
            focus: true
            placeholderText: root.page === "emoji" ? i18n("Search emoji") : i18n("Search the clipboard")
            visible: root.page === "emoji" || root.history.count > 0

            onTextChanged: list.currentIndex = list.count > 0 ? 0 : -1
            onNavigateDown: {
                list.incrementCurrentIndex();
                list.positionViewAtIndex(list.currentIndex, ListView.Contain);
            }
            onNavigateUp: {
                list.decrementCurrentIndex();
                list.positionViewAtIndex(list.currentIndex, ListView.Contain);
            }
            onAccepted: root.chooseCurrent()
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 12
            Layout.preferredHeight: contentHeight
            Layout.minimumHeight: Math.min(contentHeight, 120)
            visible: root.page === "clipboard" && count > 0
            clip: true
            model: filtered
            currentIndex: 0
            spacing: M3.slabGap
            boundsBehavior: Flickable.StopAtBounds
            keyNavigationEnabled: false
            highlightFollowsCurrentItem: false

            delegate: ClipItem {
                width: ListView.view.width
                first: index === 0
                last: index === ListView.view.count - 1
                current: ListView.isCurrentItem
                onHoveredChanged: {
                    if (hovered) {
                        list.currentIndex = index;
                    }
                }
                onChosen: root.choose(uuid)
                onRemoveRequested: root.history.remove(uuid)
            }

            MScrollIndicator {
                flickable: list
                visible: scrollable
            }
        }

        UI.EmptyState {
            Layout.fillWidth: true
            Layout.bottomMargin: 16
            visible: root.page === "clipboard" && list.count === 0
            icon: root.history.count > 0 ? "search" : "edit-paste"
            title: root.history.count > 0 ? i18n("No matches") : i18n("Nothing copied yet")
            text: root.history.count > 0 ? "" : i18n("Text and pictures you copy show up here")
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 12
            Layout.bottomMargin: 4
            Layout.rightMargin: 4
            visible: root.page === "clipboard" && root.history.count > 0

            Item {
                Layout.fillWidth: true
            }

            MButton {
                variant: "tonal"
                icon: "edit-clear-history"
                text: i18n("Clear all")
                onClicked: {
                    root.history.clearHistory();
                    search.clear();
                }
            }
        }

        Loader {
            id: emojiLoader
            Layout.fillWidth: true
            Layout.topMargin: 12
            Layout.preferredHeight: 380
            visible: root.page === "emoji"
            active: root.page === "emoji" || item !== null
            sourceComponent: EmojiPage {
                query: root.page === "emoji" ? search.text : ""
                recent: root.recentEmoji
                onChosen: emoji => root.chooseEmoji(emoji)
            }
        }
    }
}
