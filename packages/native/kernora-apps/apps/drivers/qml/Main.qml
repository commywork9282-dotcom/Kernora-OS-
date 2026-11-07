/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
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

    readonly property string tool: "/usr/libexec/kernora-drivers"
    readonly property string scanner: "/usr/libexec/kernora-hardware"
    readonly property url jobFile: "file:///run/kernora-drivers/job.json"
    readonly property string language: i18nc("Language key of the driver catalog: ru in Russian", "en")

    property string tab: "drivers"
    property var hardware: ({})
    property var nvidia: ({})
    property var job: ({})
    property bool loaded: false
    property string jobName: ""
    property string jobFailure: ""
    property string nvidiaRequest: ""
    property real nvidiaRequestedAt: 0
    property bool nvidiaFailed: false

    readonly property var machine: hardware.machine || ({})
    readonly property var items: hardware.items || []
    readonly property var devices: hardware.devices || []
    readonly property bool live: machine.live === true
    readonly property bool jobActive: job.state === "queued" || job.state === "running"
    readonly property string jobTitle: {
        if (jobName.length > 0) {
            return jobName;
        }
        const item = items.find(entry => entry.id === job.id);
        return item ? pick(item.name) : "";
    }
    readonly property bool nvidiaBusy: nvidiaRequest.length > 0 || nvidia.status === "installing" || nvidia.status === "removing"
    readonly property bool busy: jobActive || nvidiaBusy
    readonly property bool restartNeeded: job.restart === true || nvidia.status === "ready" || Updates.restartNeeded

    width: 980
    height: 700
    minimumWidth: 680
    minimumHeight: 480
    color: M3.surfaceContainer
    visible: true
    title: i18n("Drivers")

    function pick(texts: var): string {
        return texts ? (texts[app.language] || texts.en || "") : "";
    }

    function refresh(): void {
        Process.run(app.scanner, ["scan"], (code, output) => {
            if (code !== 0) {
                return;
            }
            try {
                const scan = JSON.parse(output);
                app.hardware = scan;
                app.nvidia = scan.nvidia || {};
                app.loaded = true;
            } catch (error) {
                console.warn(error);
            }
        });
    }

    function refreshNvidia(): void {
        Process.run(app.tool, ["status"], (code, output) => {
            const values = {};
            for (const line of output.split("\n")) {
                const at = line.indexOf("=");
                if (at > 0) {
                    values[line.slice(0, at)] = line.slice(at + 1);
                }
            }
            if (app.nvidiaRequest.length > 0 && Number(values.time || 0) >= app.nvidiaRequestedAt) {
                app.nvidiaRequest = "";
                app.refresh();
            }
            app.nvidia = values;
        });
    }

    function readJob(): void {
        const file = Files.readText(app.jobFile);
        let next = {};
        if (file.ok) {
            try {
                next = JSON.parse(file.text);
            } catch (error) {
                return;
            }
        }
        const running = app.jobActive;
        app.job = next;
        if (running && !app.jobActive) {
            app.finished(next);
        }
    }

    function failure(values: var): string {
        switch (values.error) {
        case "offline":
            return i18n("There's no internet connection. Connect and try again.");
        case "secureboot":
            return i18n("This driver can't load while Secure Boot is on.");
        case "live":
            return i18n("Install Kernora on this computer first.");
        case "sources":
            return i18n("Kernora couldn't reach the download server. Try again later.");
        case "conflict":
            return i18n("It doesn't work together with other installed software. Nothing was changed.");
        case "in-use":
            return i18n("Other apps still need it: %1", values.detail);
        case "foreign":
            return i18n("This wasn't installed from Drivers, so it can't be removed here.");
        case "flash":
            return (values.detail || "").length > 0 ? i18n("The firmware wasn't updated: %1", values.detail)
                                                    : i18n("The firmware wasn't updated.");
        }
        return values.action === "drop" ? i18n("It couldn't be removed. Try again.")
                                        : i18n("It couldn't be installed. Nothing was changed.");
    }

    function finished(values: var): void {
        if (values.state === "failed") {
            app.jobFailure = app.failure(values);
        } else if (values.action === "flash") {
            app.showMessage(i18n("Firmware updated"), "", null);
        } else if (values.action === "drop") {
            app.showMessage(i18n("%1 removed", app.jobTitle), "", null);
        } else {
            app.showMessage(i18n("%1 installed", app.jobTitle), "", null);
        }
        app.jobName = "";
        app.refresh();
    }

    function request(action: string, name: string, label: string): void {
        app.jobName = label;
        app.jobFailure = "";
        Process.run("pkexec", [app.tool, "request", action, name], code => {
            if (code === 0) {
                app.readJob();
            } else if (code === 3) {
                app.showMessage(i18n("Another install is still running. Try again when it finishes."), "", null);
            } else if (code === 127) {
                app.showMessage(i18n("Kernora didn't get permission to do this."), "", null);
            } else if (code !== 126) {
                app.showMessage(i18n("Kernora couldn't start this. Install the latest updates and try again."), "", null);
            }
        });
    }

    function requestNvidia(action: string): void {
        app.nvidiaFailed = false;
        Process.run("pkexec", [app.tool, "request", action], code => {
            app.nvidiaFailed = code !== 0 && code !== 126 && code !== 127;
            if (code === 127) {
                app.showMessage(i18n("Kernora didn't get permission to do this."), "", null);
            }
            if (code === 0) {
                app.nvidiaRequestedAt = Math.floor(Date.now() / 1000);
                app.nvidiaRequest = action;
            }
            app.refreshNvidia();
        });
    }

    function restart(): void {
        DBus.call("session", "org.kde.LogoutPrompt", "/LogoutPrompt", "org.kde.LogoutPrompt", "promptReboot", [], null);
    }

    function openPage(file: string, properties: var): void {
        stack.push(Qt.resolvedUrl(file), Object.assign({window: app}, properties || {}));
    }

    function goBack(): void {
        if (stack.depth > 1) {
            stack.pop();
        }
    }

    onTabChanged: stack.pop(null, QQC2.StackView.Immediate)
    onActiveChanged: {
        if (active && loaded && !busy) {
            refresh();
        }
    }

    Component.onCompleted: {
        readJob();
        refresh();
    }

    Timer {
        interval: 1000
        repeat: true
        running: app.jobActive
        onTriggered: app.readJob()
    }

    Timer {
        interval: app.nvidiaBusy ? 2000 : 6000
        repeat: true
        running: app.nvidiaBusy || (app.active && (app.nvidia.device || "").length > 0)
        onTriggered: app.refreshNvidia()
    }

    Shortcut {
        sequence: "Alt+Left"
        onActivated: app.goBack()
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
                key: "drivers"
                icon: "kernora-drivers"
                label: i18n("Drivers")
            }
            RailItem {
                key: "devices"
                icon: "kernora-devices"
                label: i18n("Devices")
            }
            RailItem {
                key: "updates"
                icon: "system-software-update"
                label: i18n("Updates")
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

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                QQC2.StackView {
                    id: stack
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    initialItem: tabs

                    pushEnter: Transition {
                        ParallelAnimation {
                            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: M3.durationMedium2 }
                            NumberAnimation { property: "x"; from: 48; to: 0; duration: M3.durationMedium4; easing.type: Easing.OutCubic }
                        }
                    }
                    pushExit: Transition {
                        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: M3.durationShort4 }
                    }
                    popEnter: Transition {
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: M3.durationMedium2 }
                    }
                    popExit: Transition {
                        ParallelAnimation {
                            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: M3.durationShort4 }
                            NumberAnimation { property: "x"; from: 0; to: 48; duration: M3.durationMedium2; easing.type: Easing.InCubic }
                        }
                    }

                    StackLayout {
                        id: tabs
                        currentIndex: ["drivers", "devices", "updates"].indexOf(app.tab)

                        DriversPage {
                            window: app
                        }
                        DevicesPage {
                            window: app
                        }
                        UpdatesPage {
                            window: app
                            active: app.tab === "updates"
                        }
                    }
                }

                JobBar {
                    Layout.fillWidth: true
                    window: app
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
