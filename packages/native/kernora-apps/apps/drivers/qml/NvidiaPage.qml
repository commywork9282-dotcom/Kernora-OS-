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

Page {
    id: page

    required property var window

    readonly property var info: window.nvidia
    readonly property bool installed: info.installed === "yes"
    readonly property bool busy: window.nvidiaBusy
    readonly property bool ready: info.status === "ready"
    readonly property bool failed: info.status === "failed" && !busy
    readonly property bool offline: info.status === "offline" && !busy
    readonly property bool blocked: info.secureboot === "yes" && !installed
    readonly property bool liveSession: info.live === "yes"
    readonly property string card: (info.name || "").length > 0 ? info.name : i18n("NVIDIA graphics card")

    title: i18n("NVIDIA driver")
    subtitle: card
    canGoBack: true
    maximumContentWidth: 720
    onBack: window.goBack()

    readonly property string detail: {
        if (window.nvidiaFailed) {
            return i18n("Kernora couldn't start this. Install the latest updates and try again.");
        }
        if (liveSession) {
            return i18n("The installer sets up the driver for %1 when the computer is online.", card);
        }
        if (busy) {
            return i18n("It takes a few minutes. You can keep using the computer.");
        }
        if (ready) {
            return i18n("The driver is installed. It starts working after a restart.");
        }
        if (installed) {
            return (info.version || "").length > 0 ? i18n("This card uses the NVIDIA driver %1.", info.version)
                                                   : i18n("This card uses the NVIDIA driver.");
        }
        if (blocked) {
            return i18n("The NVIDIA driver can't load while Secure Boot is on. Turn it off in the computer's firmware settings, then try again.");
        }
        if (failed) {
            return i18n("The driver couldn't be installed. Check the internet connection and try again.");
        }
        if (offline) {
            return i18n("There's no internet connection. The driver will be installed when the computer is online.");
        }
        if (info.status === "removed") {
            return i18n("The NVIDIA driver is removed and stops being used after a restart.");
        }
        return info.automatic === "yes"
            ? i18n("The NVIDIA driver will be installed automatically as soon as the computer is online.")
            : i18n("Install the NVIDIA driver to get the full speed of this card.");
    }

    Group {
        ListItem {
            title: {
                if (page.busy) {
                    return page.window.nvidiaRequest === "remove" || page.info.status === "removing"
                        ? i18n("Removing…") : i18n("Installing…");
                }
                return page.installed ? i18n("Installed") : i18n("Not installed");
            }
            subtitle: page.detail
            icon: page.failed || page.blocked ? "dialog-error" : page.ready ? "system-reboot" : page.installed ? "dialog-positive" : "video-card"
            accent: 1
            maximumSubtitleLines: 4
            interactive: false
            trailing: Component {
                RowLayout {
                    spacing: 8
                    MButton {
                        visible: page.ready
                        text: i18n("Restart")
                        onClicked: page.window.restart()
                    }
                    MButton {
                        visible: !page.installed && !page.busy && !page.liveSession
                        enabled: !page.window.jobActive
                        variant: "tonal"
                        text: page.failed || page.blocked ? i18n("Try again") : i18n("Install")
                        onClicked: page.window.requestNvidia("install")
                    }
                    MButton {
                        visible: page.installed && !page.busy && !page.liveSession
                        enabled: !page.window.jobActive
                        variant: "text"
                        text: i18n("Remove")
                        onClicked: removal.open()
                    }
                }
            }
        }
        ListItem {
            visible: !page.liveSession
            title: i18n("Install automatically")
            subtitle: i18n("When a graphics card needs a driver, Kernora installs it and asks you to restart")
            icon: "download"
            iconStyle: "plain"
            checkable: true
            checked: page.info.automatic !== "no"
            onToggled: on => Process.run("pkexec", [page.window.tool, "set-automatic", on ? "on" : "off"], () => page.window.refreshNvidia())
        }
    }

    Dialog {
        id: removal
        title: i18n("Remove the NVIDIA driver?")
        text: i18n("The card goes back to the built-in open driver after a restart.")
        destructive: true
        acceptText: i18n("Remove")
        onAccepted: page.window.requestNvidia("remove")
    }
}
