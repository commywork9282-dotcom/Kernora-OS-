/*
    SPDX-FileCopyrightText: 2026 Lumo contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kernora.m3
import org.kernora.ui
import org.kernora.system

AppWindow {
    id: app

    width: 860
    height: 640
    minimumWidth: 520
    minimumHeight: 460
    visible: true
    title: i18n("Task Manager")

    property string view: "processes"
    property var snapshot: ({ cpu: 0, memoryTotal: 0, memoryUsed: 0, gpu: -1, disk: 0, received: 0, sent: 0, processes: [] })
    property string sortKey: "cpu"
    property bool everything: false
    property int selected: -1
    property var cpuHistory: []
    property var memoryHistory: []
    property var gpuHistory: []
    property var diskHistory: []
    property var networkHistory: []
    property int startupRevision: 0

    readonly property var processes: {
        const query = search.text.trim().toLowerCase();
        return snapshot.processes
            .filter(p => (everything || p.mine) && (query.length === 0 || p.name.toLowerCase().includes(query)))
            .sort((a, b) => sortKey === "name" ? a.name.localeCompare(b.name)
                : sortKey === "memory" ? b.memory - a.memory : (b.cpu - a.cpu) || (b.memory - a.memory));
    }
    readonly property var selectedProcess: snapshot.processes.find(p => p.pid === selected) || null

    function handleArguments(args: var): void {}

    function push(list: var, value: real): var {
        const next = list.concat([value]);
        return next.length > 60 ? next.slice(next.length - 60) : next;
    }

    function refresh(): void {
        const data = Tasks.sample();
        snapshot = data;
        cpuHistory = push(cpuHistory, data.cpu);
        memoryHistory = push(memoryHistory, data.memoryTotal > 0 ? 100 * data.memoryUsed / data.memoryTotal : 0);
        gpuHistory = push(gpuHistory, Math.max(0, data.gpu));
        diskHistory = push(diskHistory, data.disk);
        networkHistory = push(networkHistory, data.received + data.sent);
    }

    function bytes(value: real): string {
        const units = [i18n("B"), i18n("KB"), i18n("MB"), i18n("GB"), i18n("TB")];
        let size = value;
        let unit = 0;
        while (size >= 1024 && unit < units.length - 1) {
            size /= 1024;
            unit += 1;
        }
        return (unit === 0 ? Math.round(size) : size.toFixed(size < 10 ? 1 : 0)) + " " + units[unit];
    }

    function endSelected(force: bool): void {
        const process = selectedProcess;
        if (!process) {
            return;
        }
        if (Tasks.end(process.pid, force)) {
            showMessage(i18n("Ended %1", process.name), "", null);
            selected = -1;
        } else {
            showMessage(i18n("Couldn't end %1", process.name), "", null);
        }
        refreshTimer.restart();
        refresh();
    }

    Component.onCompleted: refresh()

    Timer {
        id: refreshTimer
        interval: 1500
        running: true
        repeat: true
        onTriggered: app.refresh()
    }

    Shortcut { sequence: "Delete"; enabled: app.selectedProcess !== null && app.view === "processes"; onActivated: app.endSelected(false) }
    Shortcut { sequence: "Ctrl+F"; onActivated: { app.view = "processes"; search.forceActiveFocus(); } }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            SegmentedButtons {
                Layout.preferredWidth: 420
                options: [
                    { value: "processes", label: i18n("Processes"), icon: "view-list-details" },
                    { value: "performance", label: i18n("Performance"), icon: "kernora-speed" },
                    { value: "startup", label: i18n("Startup apps"), icon: "system-run" }
                ]
                currentValue: app.view
                onSelected: value => app.view = value
            }
            Item { Layout.fillWidth: true }
            MText {
                role: "labelLarge"
                color: M3.surfaceVariantContent
                text: i18n("CPU %1%  ·  Memory %2", Math.round(app.snapshot.cpu), app.bytes(app.snapshot.memoryUsed))
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: app.view === "processes"
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                SearchField {
                    id: search
                    Layout.fillWidth: true
                    placeholderText: i18n("Search processes")
                }
                QQC2.CheckBox {
                    text: i18n("Show all users")
                    checked: app.everything
                    onToggled: app.everything = checked
                }
                QQC2.Button {
                    text: i18n("End task")
                    highlighted: true
                    enabled: app.selectedProcess !== null && app.selectedProcess.mine
                    onClicked: app.endSelected(false)
                }
                QQC2.Button {
                    text: i18n("Force")
                    flat: true
                    enabled: app.selectedProcess !== null && app.selectedProcess.mine
                    onClicked: app.endSelected(true)
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: M3.classic ? M3.cornerCard : 20
                color: M3.surfaceContainer
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 20
                        Layout.rightMargin: 20
                        Layout.topMargin: 12
                        Layout.bottomMargin: 8
                        spacing: 12
                        HeaderLabel { Layout.fillWidth: true; key: "name"; text: i18n("Name") }
                        HeaderLabel { Layout.preferredWidth: 80; key: "cpu"; text: i18n("CPU"); alignRight: true }
                        HeaderLabel { Layout.preferredWidth: 100; key: "memory"; text: i18n("Memory"); alignRight: true }
                    }

                    ListView {
                        id: list
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: app.processes
                        reuseItems: true
                        QQC2.ScrollBar.vertical: QQC2.ScrollBar {}

                        delegate: Rectangle {
                            id: row
                            required property var modelData
                            width: ListView.view.width
                            height: 48
                            color: app.selected === modelData.pid ? M3.secondaryContainer
                                : hover.hovered ? M3.withAlpha(M3.surfaceContent, 0.06) : "transparent"

                            HoverHandler { id: hover }
                            TapHandler { onTapped: app.selected = row.modelData.pid }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 20
                                anchors.rightMargin: 20
                                spacing: 12
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    MText {
                                        Layout.fillWidth: true
                                        role: "bodyLarge"
                                        text: row.modelData.name
                                    }
                                    MText {
                                        Layout.fillWidth: true
                                        role: "bodySmall"
                                        color: M3.surfaceVariantContent
                                        text: row.modelData.command.length > 0 ? row.modelData.command : i18n("Process %1", row.modelData.pid)
                                    }
                                }
                                MText {
                                    Layout.preferredWidth: 80
                                    horizontalAlignment: Text.AlignRight
                                    role: "bodyMedium"
                                    text: row.modelData.cpu.toFixed(1) + "%"
                                    color: row.modelData.cpu >= 50 ? M3.error : M3.surfaceContent
                                }
                                MText {
                                    Layout.preferredWidth: 100
                                    horizontalAlignment: Text.AlignRight
                                    role: "bodyMedium"
                                    text: app.bytes(row.modelData.memory)
                                }
                            }
                        }
                    }
                }
            }
        }

        QQC2.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: app.view === "performance"
            contentWidth: availableWidth

            GridLayout {
                width: parent.width
                columns: width >= 700 ? 2 : 1
                columnSpacing: 12
                rowSpacing: 12

                Meter {
                    title: i18n("Processor")
                    value: Math.round(app.snapshot.cpu) + "%"
                    detail: i18n("%1 threads", app.snapshot.threads || 0)
                    history: app.cpuHistory
                    maximum: 100
                    accent: M3.primary
                }
                Meter {
                    title: i18n("Memory")
                    value: app.bytes(app.snapshot.memoryUsed) + " / " + app.bytes(app.snapshot.memoryTotal)
                    detail: app.snapshot.swapTotal > 0 ? i18n("Swap %1 / %2", app.bytes(app.snapshot.swapUsed), app.bytes(app.snapshot.swapTotal)) : ""
                    history: app.memoryHistory
                    maximum: 100
                    accent: M3.tertiary
                }
                Meter {
                    title: i18n("Graphics")
                    value: app.snapshot.gpu >= 0 ? app.snapshot.gpu + "%" : i18n("Not reported")
                    detail: app.snapshot.gpu >= 0 ? SystemInfo.graphics : i18n("This graphics driver doesn't report how busy it is.")
                    history: app.gpuHistory
                    maximum: 100
                    accent: M3.secondary
                }
                Meter {
                    title: i18n("Disk")
                    value: i18n("%1/s", app.bytes(app.snapshot.disk))
                    detail: i18n("Read and write")
                    history: app.diskHistory
                    maximum: Math.max(1024 * 1024, ...app.diskHistory)
                    accent: M3.primary
                }
                Meter {
                    title: i18n("Network")
                    value: i18n("↓ %1/s  ↑ %2/s", app.bytes(app.snapshot.received), app.bytes(app.snapshot.sent))
                    detail: i18n("All connections")
                    history: app.networkHistory
                    maximum: Math.max(64 * 1024, ...app.networkHistory)
                    accent: M3.tertiary
                }
            }
        }

        QQC2.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: app.view === "startup"
            contentWidth: availableWidth

            ColumnLayout {
                width: parent.width
                spacing: 12

                MText {
                    Layout.fillWidth: true
                    role: "bodyMedium"
                    color: M3.surfaceVariantContent
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                    text: i18n("These apps start when you log in. Turning one off makes logging in faster.")
                }

                Group {
                    Layout.fillWidth: true
                    Repeater {
                        model: { app.startupRevision; return Autostart.entries(); }
                        delegate: ListItem {
                            id: startupRow
                            required property var modelData
                            title: modelData.name
                            subtitle: modelData.comment || ""
                            leading: Component {
                                AppIcon {
                                    name: startupRow.modelData.icon || ""
                                }
                            }
                            checkable: true
                            checked: modelData.enabled
                            onToggled: on => {
                                Autostart.setEnabled(modelData.id, on);
                                app.startupRevision += 1;
                            }
                        }
                    }
                }
            }
        }
    }

    component HeaderLabel: MText {
        property string key
        property bool alignRight: false
        role: "labelLarge"
        color: app.sortKey === key ? M3.primary : M3.surfaceVariantContent
        horizontalAlignment: alignRight ? Text.AlignRight : Text.AlignLeft
        TapHandler { onTapped: app.sortKey = parent.key }
    }

    component Meter: Rectangle {
        id: meter
        property string title
        property string value
        property string detail
        property var history: []
        property real maximum: 100
        property color accent: M3.primary

        Layout.fillWidth: true
        implicitHeight: 200
        radius: M3.classic ? M3.cornerCard : 24
        color: M3.surfaceContainer

        onHistoryChanged: graph.requestPaint()

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 4
            MText { role: "titleMedium"; text: meter.title }
            MText { role: "headlineSmall"; text: meter.value; color: meter.accent }
            MText {
                Layout.fillWidth: true
                role: "bodySmall"
                color: M3.surfaceVariantContent
                text: meter.detail
                visible: text.length > 0
            }
            Canvas {
                id: graph
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: 8
                onPaint: {
                    const context = getContext("2d");
                    context.reset();
                    const points = meter.history;
                    if (points.length < 2 || meter.maximum <= 0) {
                        return;
                    }
                    const step = width / 59;
                    const start = width - (points.length - 1) * step;
                    context.beginPath();
                    context.moveTo(start, height);
                    for (let i = 0; i < points.length; i++) {
                        context.lineTo(start + i * step, height - Math.min(1, points[i] / meter.maximum) * height);
                    }
                    context.lineTo(width, height);
                    context.closePath();
                    context.fillStyle = Qt.rgba(meter.accent.r, meter.accent.g, meter.accent.b, 0.18);
                    context.fill();
                    context.beginPath();
                    for (let i = 0; i < points.length; i++) {
                        const x = start + i * step;
                        const y = height - Math.min(1, points[i] / meter.maximum) * height;
                        if (i === 0) {
                            context.moveTo(x, y);
                        } else {
                            context.lineTo(x, y);
                        }
                    }
                    context.strokeStyle = meter.accent;
                    context.lineWidth = 2;
                    context.stroke();
                }
            }
        }
    }
}
