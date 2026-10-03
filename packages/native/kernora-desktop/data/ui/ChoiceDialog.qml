/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kernora.m3

Dialog {
    id: root

    property var options: []
    property var currentValue
    property bool searchable: options.length > 12
    signal chosen(var value)

    showAccept: false
    rejectText: (typeof i18nd === "function" ? i18nd("kernora-ui", "Cancel") : qsTr("Cancel"))
    preferredWidth: 460

    function showCurrent(): void {
        const index = root.filtered.findIndex(o => o.value === root.currentValue);
        if (index >= 0) {
            list.positionViewAtIndex(index, ListView.Center);
        }
    }
    onAboutToShow: {
        search.text = "";
        Qt.callLater(() => {
            root.showCurrent();
            if (root.searchable) {
                search.forceActiveFocus();
            }
        });
    }
    onOpened: showCurrent()

    readonly property var filtered: {
        const needle = search.text.trim().toLowerCase();
        if (needle.length === 0) {
            return options;
        }
        return options.filter(o => String(o.label).toLowerCase().includes(needle)
                                 || String(o.description || "").toLowerCase().includes(needle));
    }

    SearchField {
        id: search
        Layout.fillWidth: true
        visible: root.searchable
        placeholderText: (typeof i18nd === "function" ? i18nd("kernora-ui", "Search") : qsTr("Search"))
    }

    ListView {
        id: list
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 420)
        clip: true
        model: root.filtered
        boundsBehavior: Flickable.StopAtBounds
        delegate: RadioRow {
            required property var modelData
            width: ListView.view.width
            title: modelData.label
            subtitle: modelData.description || ""
            appIcon: modelData.appIcon || ""
            checked: modelData.value === root.currentValue
            onClicked: {
                root.chosen(modelData.value);
                root.close();
            }
        }
        QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
    }
}
