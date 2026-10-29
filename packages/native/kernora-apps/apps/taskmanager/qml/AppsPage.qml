/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

TaskPage {
    id: page

    title: i18n("Apps")
    placeholder: i18n("Search apps")
    actionText: i18n("End task")
    emptyIcon: "view-app-grid"
    emptyTitle: sourceModel && sourceModel.available === false ? i18n("Apps can't be listed here") : i18n("No apps are open")
    emptyText: sourceModel && sourceModel.available === false ? i18n("This system doesn't group processes by app.") : ""
    nameColumn: 0
    cpuColumn: 1
    memoryColumn: 2
    iconColumn: 3
    acceptRow: (row, parent) => {
        const source = page.sourceModel;
        const pids = source.data(source.index(row, 0, parent), page.window.pidsRole);
        if (!pids || pids.length === 0) {
            return false;
        }
        if (page.searchText.length === 0) {
            return true;
        }
        return String(source.data(source.index(row, 0, parent), page.window.valueRole)).toLowerCase().includes(page.searchText);
    }
}
