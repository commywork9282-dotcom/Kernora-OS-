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
import org.kde.ksysguard.process as Procs
import org.kde.ksysguard.sensors as Sensors

AppWindow {
    id: app

    width: 1000
    height: 680
    minimumWidth: 760
    minimumHeight: 480
    color: M3.surfaceContainer
    visible: true
    title: i18n("Task Manager")

    property string tab: "apps"
    property string user: ""
    property int tick: 0
    property var appPids: ({})
    property string appPidsKey: ""

    readonly property int valueRole: Procs.ProcessDataModel.Value
    readonly property int formattedRole: Procs.ProcessDataModel.FormattedValue
    readonly property int pidsRole: Procs.ProcessDataModel.PIDs

    function cell(model: var, row: int, column: int, role: int): var {
        return model.data(model.index(row, column), role);
    }

    function collectAppPids(): void {
        const pids = {};
        for (let row = 0; row < applications.rowCount(); ++row) {
            const list = applications.data(applications.index(row, 0), pidsRole) || [];
            for (const pid of list) {
                pids[pid] = true;
            }
        }
        const key = Object.keys(pids).sort().join(",");
        if (key !== appPidsKey) {
            appPidsKey = key;
            appPids = pids;
        }
    }

    function endProcesses(pids: var, name: string, force: bool): void {
        const result = controller.sendSignal(pids, force ? Procs.ProcessController.KillSignal : Procs.ProcessController.TerminateSignal);
        if (result !== Procs.ProcessController.Success && result !== Procs.ProcessController.NoSuchProcess) {
            if (result !== Procs.ProcessController.UserCancelled) {
                app.showMessage(i18n("Couldn't end %1: %2", name, controller.resultToString(result)), "", null);
            }
            return;
        }
        if (!force) {
            stillRunning.pids = pids;
            stillRunning.name = name;
            stillRunning.restart();
        }
    }

    Component.onCompleted: Process.run("id", ["-un"], (code, output) => app.user = code === 0 ? output.trim() : "")

    Shortcut {
        sequences: [StandardKey.Find]
        onActivated: {
            if (app.tab === "apps") {
                appsPage.focusSearch();
            } else if (app.tab === "processes") {
                processesPage.focusSearch();
            }
        }
    }

    Timer {
        interval: 1000
        running: app.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            app.tick++;
            app.collectAppPids();
        }
    }

    Timer {
        id: stillRunning
        property var pids: []
        property string name
        interval: 5000
        onTriggered: {
            const alive = pids.filter(pid => Files.exists("file:///proc/" + pid));
            if (alive.length > 0) {
                app.showMessage(i18n("%1 isn't closing", name), i18n("Force quit"), () => app.endProcesses(alive, name, true));
            }
        }
    }

    Procs.ApplicationDataModel {
        id: applications
        enabledAttributes: ["appName", "usage", "memory", "iconName"]
    }

    Procs.ProcessController {
        id: controller
    }

    Sensors.Sensor {
        id: cpuTotal
        sensorId: "cpu/all/usage"
        updateRateLimit: 1000
    }

    Sensors.Sensor {
        id: memoryTotal
        sensorId: "memory/physical/usedPercent"
        updateRateLimit: 1000
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        ColumnLayout {
            Layout.fillHeight: true
            Layout.fillWidth: false
            Layout.preferredWidth: 96
            Layout.maximumWidth: 96
            Layout.topMargin: 16
            spacing: 4

            RailItem {
                key: "apps"
                icon: "view-app-grid"
                label: i18n("Apps")
            }
            RailItem {
                key: "processes"
                icon: "view-list-details"
                label: i18n("Processes")
            }
            RailItem {
                key: "performance"
                icon: "speedometer"
                label: i18n("Performance")
            }
            Item {
                Layout.fillHeight: true
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 12
            Layout.rightMargin: 12
            Layout.bottomMargin: 12
            radius: M3.classic ? M3.cornerCard : 24
            color: M3.surface
            clip: true

            StackLayout {
                anchors.fill: parent
                currentIndex: ["apps", "processes", "performance"].indexOf(app.tab)

                AppsPage {
                    id: appsPage
                    window: app
                    sourceModel: applications
                    cpuTotal: cpuTotal.formattedValue
                    memoryTotal: memoryTotal.formattedValue
                }
                ProcessesPage {
                    id: processesPage
                    window: app
                    active: app.tab === "processes"
                    cpuTotal: cpuTotal.formattedValue
                    memoryTotal: memoryTotal.formattedValue
                }
                PerformancePage {
                    active: app.tab === "performance"
                }
            }
        }
    }

    component RailItem: Item {
        id: rail
        required property string key
        required property string icon
        required property string label
        readonly property bool current: app.tab === key

        Layout.fillWidth: true
        Layout.preferredHeight: 72
        activeFocusOnTab: true
        Accessible.role: Accessible.PageTab
        Accessible.name: label
        Accessible.selected: current
        Keys.onSpacePressed: app.tab = key
        Keys.onReturnPressed: app.tab = key

        MMorph {
            id: morph
            active: rail.current
        }

        Item {
            id: indicator
            anchors.horizontalCenter: parent.horizontalCenter
            y: 8
            width: 56
            height: 32

            Rectangle {
                anchors.centerIn: parent
                height: parent.height
                width: M3.classic ? parent.width : parent.width * (0.5 + 0.5 * morph.value)
                radius: M3.radius("indicator", height)
                color: M3.secondaryContainer
                opacity: M3.classic ? (rail.current ? 1 : 0) : Math.min(1, morph.value * 2)
            }
            MStateLayer {
                anchors.fill: parent
                radius: M3.radius("indicator", height)
                color: M3.surfaceContent
                hovered: railMouse.containsMouse
                pressed: railMouse.pressed
            }
            MIcon {
                anchors.centerIn: parent
                size: 24
                source: rail.icon
                color: rail.current ? M3.secondaryContainerContent : M3.surfaceVariantContent
            }
        }
        MText {
            anchors.top: indicator.bottom
            anchors.topMargin: 4
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, rail.width - 8)
            horizontalAlignment: Text.AlignHCenter
            role: rail.current ? "labelMediumEmphasized" : "labelMedium"
            color: rail.current ? M3.surfaceContent : M3.surfaceVariantContent
            text: rail.label
        }
        MouseArea {
            id: railMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: app.tab = rail.key
        }
    }
}
