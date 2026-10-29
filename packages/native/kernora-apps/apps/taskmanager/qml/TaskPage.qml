/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kernora.m3
import org.kernora.ui
import org.kernora.system
import org.kde.kitemmodels as KItemModels

Item {
    id: page

    required property var window
    property var sourceModel
    property string title
    property string placeholder
    property string actionText
    property string emptyIcon
    property string emptyTitle
    property string emptyText
    property string cpuTotal
    property string memoryTotal
    property int nameColumn: 0
    property int cpuColumn: 1
    property int memoryColumn: 2
    property int iconColumn: -1
    property int pidColumn: -1
    property int userColumn: -1
    property var acceptRow: (row, parent) => true
    property string sortKey: "memory"
    property string selected: ""
    readonly property string searchText: search.text.trim().toLowerCase()
    default property alias filters: filterRow.data

    function segmentsWidth(options: var): real {
        const widest = Math.max(...options.map(option => labelMetrics.advanceWidth(option.label)));
        return Math.ceil(options.length * (widest + 58) + 2 * (options.length - 1));
    }

    function focusSearch(): void {
        search.forceActiveFocus();
    }

    function refilter(): void {
        proxy.invalidateFilter();
    }

    function valid(row: int, column: int): bool {
        return row >= 0 && column >= 0 && row < proxy.rowCount() && column < proxy.columnCount();
    }

    function value(row: int, column: int): var {
        return valid(row, column) ? proxy.data(proxy.index(row, column), page.window.valueRole) : undefined;
    }

    function text(row: int, column: int): string {
        return valid(row, column) ? String(proxy.data(proxy.index(row, column), page.window.formattedRole) ?? "") : "";
    }

    function pidsOf(row: int): var {
        if (page.pidColumn >= 0) {
            const pid = Number(value(row, page.pidColumn));
            return pid > 0 ? [pid] : [];
        }
        return valid(row, 0) ? Array.from(proxy.data(proxy.index(row, 0), page.window.pidsRole) || []) : [];
    }

    function cpuText(row: int): string {
        const share = Number(value(row, page.cpuColumn) || 0) / Math.max(1, SystemInfo.cpuThreads);
        return i18nc("CPU share of a process", "%1%", share.toLocaleString(Qt.locale(), "f", 1));
    }

    function keyOf(row: int): string {
        return page.pidColumn >= 0 ? String(value(row, page.pidColumn)) : String(value(row, page.nameColumn));
    }

    function endSelected(): void {
        for (let row = 0; row < proxy.rowCount(); ++row) {
            if (keyOf(row) === page.selected) {
                confirm.pids = pidsOf(row);
                confirm.name = String(value(row, page.nameColumn));
                confirm.open();
                return;
            }
        }
        page.selected = "";
    }

    onSearchTextChanged: proxy.invalidateFilter()

    FontMetrics {
        id: labelMetrics
        font: M3.labelLarge
    }

    KItemModels.KSortFilterProxyModel {
        id: proxy
        sourceModel: page.sourceModel
        sortRoleName: "Value"
        sortColumn: page.sortKey === "name" ? page.nameColumn : page.sortKey === "cpu" ? page.cpuColumn : page.memoryColumn
        sortOrder: page.sortKey === "name" ? Qt.AscendingOrder : Qt.DescendingOrder
        sortCaseSensitivity: Qt.CaseInsensitive
        filterRowCallback: (row, parent) => page.acceptRow(row, parent)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        anchors.bottomMargin: 12
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            MText {
                Layout.fillWidth: true
                role: "headlineSmall"
                text: page.title
                elide: Text.ElideRight
            }
            SearchField {
                id: search
                Layout.preferredWidth: 280
                placeholderText: page.placeholder
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            RowLayout {
                id: filterRow
                spacing: 12
            }
            Item {
                Layout.fillWidth: true
            }
            MButton {
                variant: "tonal"
                icon: "process-stop"
                text: page.actionText
                enabled: page.selected.length > 0
                onClicked: page.endSelected()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            spacing: 16

            SortHeader {
                Layout.fillWidth: true
                key: "name"
                label: i18n("Name")
            }
            SortHeader {
                Layout.preferredWidth: 96
                key: "cpu"
                amount: page.cpuTotal
                label: i18n("CPU")
            }
            SortHeader {
                Layout.preferredWidth: 116
                key: "memory"
                amount: page.memoryTotal
                label: i18n("Memory")
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: list
                anchors.fill: parent
                clip: true
                spacing: 2
                model: proxy
                boundsBehavior: Flickable.StopAtBounds
                reuseItems: true

                delegate: Item {
                    id: row
                    required property int index
                    readonly property int tick: page.window.tick
                    readonly property string key: (tick, page.keyOf(index))
                    readonly property string name: (tick, String(page.value(index, page.nameColumn) ?? ""))
                    readonly property string icon: (tick, page.iconColumn >= 0 ? String(page.value(index, page.iconColumn) ?? "") : name.toLowerCase())
                    readonly property var pids: (tick, page.pidsOf(index))
                    readonly property string subtitle: {
                        tick;
                        if (page.pidColumn >= 0) {
                            const user = page.userColumn >= 0 ? String(page.value(index, page.userColumn) ?? "") : "";
                            const pid = String(page.value(index, page.pidColumn));
                            return user.length > 0 ? i18n("PID %1 · %2", pid, user) : i18n("PID %1", pid);
                        }
                        return i18np("%1 process", "%1 processes", pids.length);
                    }
                    readonly property bool current: key === page.selected

                    width: ListView.view.width
                    height: 60

                    Rectangle {
                        anchors.fill: parent
                        radius: M3.classic ? M3.cornerListItem : 16
                        color: row.current ? M3.secondaryContainer : "transparent"
                    }
                    MStateLayer {
                        anchors.fill: parent
                        radius: M3.classic ? M3.cornerListItem : 16
                        color: row.current ? M3.secondaryContainerContent : M3.surfaceContent
                        hovered: mouse.containsMouse
                        pressed: mouse.pressed
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 16

                        AppIcon {
                            size: 32
                            name: row.icon
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            MText {
                                Layout.fillWidth: true
                                role: "bodyLarge"
                                text: row.name
                                color: row.current ? M3.secondaryContainerContent : M3.surfaceContent
                                elide: Text.ElideRight
                            }
                            MText {
                                Layout.fillWidth: true
                                role: "bodySmall"
                                text: row.subtitle
                                color: M3.surfaceVariantContent
                                elide: Text.ElideRight
                            }
                        }
                        MText {
                            Layout.preferredWidth: 96
                            horizontalAlignment: Text.AlignRight
                            role: "bodyMedium"
                            text: (row.tick, page.cpuText(row.index))
                            color: row.current ? M3.secondaryContainerContent : M3.surfaceContent
                        }
                        MText {
                            Layout.preferredWidth: 116
                            horizontalAlignment: Text.AlignRight
                            role: "bodyMedium"
                            text: (row.tick, page.text(row.index, page.memoryColumn))
                            color: row.current ? M3.secondaryContainerContent : M3.surfaceContent
                        }
                    }
                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: page.selected = row.current ? "" : row.key
                    }
                }
            }

            MScrollIndicator {
                flickable: list
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
            }

            EmptyState {
                anchors.centerIn: parent
                width: Math.min(parent.width, 420)
                visible: list.count === 0
                icon: page.searchText.length > 0 ? "edit-find" : page.emptyIcon
                title: page.searchText.length > 0 ? i18n("Nothing found") : page.emptyTitle
                text: page.searchText.length > 0 ? i18n("Nothing here matches “%1”.", search.text.trim()) : page.emptyText
            }
        }
    }

    Dialog {
        id: confirm
        property var pids: []
        property string name
        title: i18n("End %1?", confirm.name)
        text: i18n("Anything unsaved in it may be lost.")
        acceptText: page.actionText
        destructive: true
        onAccepted: {
            page.window.endProcesses(confirm.pids, confirm.name, false);
            page.selected = "";
        }
    }

    component SortHeader: MouseArea {
        id: header
        required property string key
        property string amount
        property string label
        readonly property bool current: page.sortKey === key
        readonly property bool total: key !== "name"

        implicitHeight: column.implicitHeight
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.ColumnHeader
        Accessible.name: label
        onClicked: page.sortKey = key

        ColumnLayout {
            id: column
            anchors.fill: parent
            spacing: 0

            MText {
                Layout.alignment: Qt.AlignRight
                visible: header.total
                role: "titleMedium"
                text: header.amount
            }
            RowLayout {
                Layout.alignment: header.total ? Qt.AlignRight : Qt.AlignLeft
                spacing: 4

                MIcon {
                    visible: header.current
                    size: 16
                    source: header.total ? "go-down" : "go-up"
                    color: M3.primary
                }
                MText {
                    role: header.total ? "labelMedium" : "labelLarge"
                    color: header.current ? M3.primary : header.containsMouse ? M3.surfaceContent : M3.surfaceVariantContent
                    text: header.label
                }
            }
        }
    }
}
