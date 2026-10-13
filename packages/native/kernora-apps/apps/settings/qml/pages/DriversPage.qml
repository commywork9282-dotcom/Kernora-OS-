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
import "../components"

SettingsPage {
    id: page

    title: i18n("Drivers")
    subtitle: i18n("Lumo finds the drivers your hardware needs and installs them by itself.")

    readonly property string tool: "/usr/libexec/kernora-drivers"
    property var info: ({})
    property bool loaded: false
    property string requested: ""
    property real requestedAt: 0
    property bool actionFailed: false

    readonly property bool hasCard: (info.device || "").length > 0
    readonly property bool supported: hasCard && info.family !== "none"
    readonly property bool installed: info.installed === "yes"
    readonly property bool installing: info.status === "installing" || requested === "install"
    readonly property bool removing: info.status === "removing" || requested === "remove"
    readonly property bool busy: installing || removing
    readonly property bool ready: info.status === "ready"
    readonly property bool failed: info.status === "failed" && !busy
    readonly property bool offline: info.status === "offline" && !busy
    readonly property bool blocked: info.secureboot === "yes" && !installed
    readonly property string card: (info.name || "").length > 0 ? info.name : i18n("NVIDIA graphics card")

    function refresh(): void {
        Process.run(page.tool, ["status"], (code, output) => {
            const values = {};
            for (const line of output.split("\n")) {
                const at = line.indexOf("=");
                if (at > 0) {
                    values[line.slice(0, at)] = line.slice(at + 1);
                }
            }
            if (page.requested.length > 0 && Number(values.time || 0) >= page.requestedAt) {
                page.requested = "";
            }
            page.info = values;
            page.loaded = true;
        });
    }

    function request(action: string): void {
        page.actionFailed = false;
        Process.run("pkexec", [page.tool, "request", action], code => {
            page.actionFailed = code !== 0 && code !== 126;
            if (code === 0) {
                page.requestedAt = Math.floor(Date.now() / 1000);
                page.requested = action;
            }
            page.refresh();
        });
    }

    Component.onCompleted: refresh()

    Timer {
        interval: page.busy ? 2000 : 6000
        running: page.visible
        repeat: true
        onTriggered: page.refresh()
    }

    readonly property string headline: {
        if (!loaded) {
            return i18n("Looking at your hardware…");
        }
        if (!hasCard) {
            return i18n("No extra drivers are needed");
        }
        if (!supported) {
            return page.card;
        }
        if (installing) {
            return i18n("Installing the driver…");
        }
        if (removing) {
            return i18n("Removing the driver…");
        }
        if (ready) {
            return i18n("Restart to use the driver");
        }
        if (installed) {
            return i18n("The driver is installed");
        }
        if (failed) {
            return i18n("The driver could not be installed");
        }
        return page.card;
    }

    readonly property string detail: {
        if (!loaded) {
            return "";
        }
        if (!hasCard) {
            return i18n("Your graphics card works with the drivers built into Lumo.");
        }
        if (actionFailed) {
            return i18n("Lumo could not start this. Install the latest updates and try again.");
        }
        if (info.live === "yes") {
            return i18n("The installer sets up the driver for %1 when the computer is online.", page.card);
        }
        if (!supported) {
            return i18n("NVIDIA no longer makes a driver for this card. It keeps working with the open driver built into Lumo.");
        }
        if (installing) {
            return i18n("Lumo is downloading the driver for %1 and installing it. It takes a few minutes, and you can keep working.", page.card);
        }
        if (removing) {
            return i18n("Lumo is removing the NVIDIA driver.");
        }
        if (ready) {
            return i18n("The driver for %1 is installed. It starts working after a restart.", page.card);
        }
        if (installed) {
            return (info.version || "").length > 0
                ? i18n("%1 uses the NVIDIA driver %2.", page.card, info.version)
                : i18n("%1 uses the NVIDIA driver.", page.card);
        }
        if (blocked) {
            return i18n("The NVIDIA driver cannot load while Secure Boot is on. Turn Secure Boot off in the computer's firmware settings, then try again.");
        }
        if (failed) {
            return i18n("Check the internet connection and try again.");
        }
        if (offline) {
            return i18n("There is no internet connection. The driver for %1 will be installed when the computer is online.", page.card);
        }
        if (info.status === "removed") {
            return i18n("The NVIDIA driver is removed and stops being used after a restart.");
        }
        return info.automatic === "yes" && info.status !== "removed"
            ? i18n("The NVIDIA driver will be installed automatically as soon as the computer is online.")
            : i18n("Install the NVIDIA driver to get the full speed of this card.");
    }

    Rectangle {
        id: summary
        width: parent.width
        implicitHeight: content.implicitHeight + 48
        radius: M3.classic ? M3.cornerCard : 28
        color: page.failed || page.blocked ? M3.errorContainer
             : page.ready ? M3.tertiaryContainer : M3.surfaceContainerHigh

        readonly property color ink: page.failed || page.blocked ? M3.errorContainerContent
             : page.ready ? M3.tertiaryContainerContent : M3.surfaceContent

        ColumnLayout {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: 24
            spacing: 12

            RowLayout {
                spacing: 16
                IconCircle {
                    size: 56
                    icon: page.failed || page.blocked ? "dialog-error"
                        : page.ready ? "system-reboot"
                        : page.installed || !page.hasCard ? "dialog-positive" : "cpu"
                    accent: 1
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    MText {
                        Layout.fillWidth: true
                        role: "titleLarge"
                        text: page.headline
                        wrapMode: Text.Wrap
                        color: summary.ink
                    }
                    MText {
                        Layout.fillWidth: true
                        role: "bodyMedium"
                        text: page.detail
                        visible: text.length > 0
                        wrapMode: Text.Wrap
                        color: summary.ink
                    }
                }
            }
            LinearProgress {
                Layout.fillWidth: true
                visible: page.busy
                indeterminate: true
            }
            RowLayout {
                spacing: 8
                visible: page.supported && !page.busy && page.info.live !== "yes"
                QQC2.Button {
                    visible: page.ready
                    text: i18n("Restart")
                    icon.name: "system-reboot"
                    highlighted: true
                    onClicked: DBus.call("session", "org.kde.LogoutPrompt", "/LogoutPrompt", "org.kde.LogoutPrompt", "promptReboot", [], null)
                }
                QQC2.Button {
                    visible: !page.installed
                    text: page.failed || page.blocked ? i18n("Try again") : i18n("Install now")
                    icon.name: "download"
                    highlighted: true
                    onClicked: page.request("install")
                }
                QQC2.Button {
                    visible: page.installed
                    text: i18n("Remove the driver")
                    icon.name: "edit-delete"
                    flat: true
                    onClicked: page.request("remove")
                }
            }
        }
    }

    Group {
        visible: page.supported && page.info.live !== "yes"

        ListItem {
            title: i18n("Install drivers automatically")
            subtitle: i18n("When a graphics card needs a driver, Lumo installs it and asks you to restart")
            icon: "download"
            iconStyle: "plain"
            checkable: true
            checked: page.info.automatic !== "no"
            onToggled: on => Process.run("pkexec", [page.tool, "set-automatic", on ? "on" : "off"], () => page.refresh())
        }
    }
}
