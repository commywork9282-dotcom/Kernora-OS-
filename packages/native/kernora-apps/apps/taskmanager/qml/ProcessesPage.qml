/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kernora.ui
import org.kde.ksysguard.process as Procs

TaskPage {
    id: page

    property bool active: false
    property string owner: "mine"

    title: i18n("Background processes")
    placeholder: i18n("Search processes")
    actionText: i18n("End process")
    emptyIcon: "view-list-details"
    emptyTitle: i18n("No background processes")
    sourceModel: processes
    nameColumn: 0
    cpuColumn: 1
    memoryColumn: 2
    pidColumn: 3
    userColumn: 4
    acceptRow: (row, parent) => {
        const read = column => processes.data(processes.index(row, column, parent), page.window.valueRole);
        if (!(read(2) > 0)) {
            return false;
        }
        if (page.window.appPids[read(3)]) {
            return false;
        }
        if (page.owner === "mine" && page.window.user.length > 0 && read(4) !== page.window.user) {
            return false;
        }
        if (page.searchText.length === 0) {
            return true;
        }
        return String(read(0)).toLowerCase().includes(page.searchText) || String(read(5)).toLowerCase().includes(page.searchText);
    }

    onOwnerChanged: refilter()

    Connections {
        target: page.window
        function onAppPidsKeyChanged(): void {
            page.refilter();
        }
        function onUserChanged(): void {
            page.refilter();
        }
    }

    Procs.ProcessDataModel {
        id: processes
        enabled: page.active
        flatList: true
        enabledAttributes: ["name", "usage", "memory", "pid", "username", "command"]
    }

    SegmentedButtons {
        id: owners
        Layout.preferredWidth: page.segmentsWidth(owners.options)
        options: [
            { value: "mine", label: i18n("Mine") },
            { value: "all", label: i18n("All users") }
        ]
        currentValue: page.owner
        onSelected: value => page.owner = value
    }
}
