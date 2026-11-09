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

    readonly property var nvidia: window.nvidia
    readonly property bool hasCard: (nvidia.device || "").length > 0
    readonly property bool cardSupported: hasCard && nvidia.family !== "none"
    readonly property bool cardNeedsDriver: cardSupported && nvidia.installed !== "yes"
    readonly property var recommended: window.items.filter(item => item.state === "available" && item.recommended)
    readonly property var optional: window.items.filter(item => item.state === "available" && !item.recommended)
    readonly property var installed: window.items.filter(item => item.state === "installed")
    readonly property int waiting: recommended.length + (cardNeedsDriver ? 1 : 0)
    readonly property var missing: window.devices.filter(device => device.status === "none" && device.offer.length === 0)
    readonly property string card: (nvidia.name || "").length > 0 ? nvidia.name : i18n("NVIDIA graphics card")

    title: i18n("Drivers")
    maximumContentWidth: 720
    subtitle: {
        if (!window.loaded) {
            return i18n("Looking at your hardware…");
        }
        if (window.live) {
            return i18n("You can add drivers after installing Kernora.");
        }
        if (waiting > 0) {
            return i18np("%1 driver is ready to install", "%1 drivers are ready to install", waiting);
        }
        return missing.length > 0 ? i18np("%1 device has no driver", "%1 devices have no driver", missing.length)
                                  : i18n("Everything is set up");
    }

    function cardState(): string {
        if (page.nvidia.status === "failed") {
            return i18n("Couldn't install the driver");
        }
        if (page.nvidia.status === "ready") {
            return i18n("Restart to use the driver");
        }
        if (page.nvidia.installed === "yes") {
            return (page.nvidia.version || "").length > 0 ? i18n("NVIDIA driver %1", page.nvidia.version) : i18n("NVIDIA driver");
        }
        if (!page.cardSupported) {
            return i18n("Uses the built-in open driver");
        }
        return page.nvidia.secureboot === "yes" ? i18n("Turn off Secure Boot to install the driver")
                                                : i18n("The NVIDIA driver is ready to install");
    }

    function detail(item: var): string {
        if (item.blocked === "secureboot" && item.state === "available") {
            return i18n("Turn off Secure Boot to use this");
        }
        return page.window.pick(item.text);
    }

    function askInstall(item: var): void {
        confirm.item = item;
        confirm.removing = false;
        confirm.open();
    }

    function askRemove(item: var): void {
        confirm.item = item;
        confirm.removing = true;
        confirm.open();
    }

    Banner {
        visible: page.window.jobFailure.length > 0
        tone: "warning"
        icon: "dialog-warning"
        title: i18n("That didn't work")
        text: page.window.jobFailure
        actionText: i18n("OK")
        onActionTriggered: page.window.jobFailure = ""
    }

    Banner {
        visible: page.window.restartNeeded
        icon: "system-reboot"
        title: i18n("Restart to finish")
        text: i18n("Your changes start working after a restart.")
        actionText: i18n("Restart")
        onActionTriggered: page.window.restart()
    }

    Group {
        title: i18n("Recommended")
        visible: page.waiting > 0

        ListItem {
            visible: page.cardNeedsDriver
            title: page.card
            subtitle: page.cardState()
            icon: "video-card"
            accent: 1
            chevron: true
            onClicked: page.window.openPage("NvidiaPage.qml", {})
        }
        Repeater {
            model: page.recommended
            delegate: ItemRow {}
        }
    }

    Group {
        title: i18n("Installed")
        visible: page.installed.length > 0 || (page.hasCard && !page.cardNeedsDriver)

        ListItem {
            visible: page.hasCard && !page.cardNeedsDriver
            title: page.card
            subtitle: page.cardState()
            icon: "video-card"
            accent: 1
            chevron: page.cardSupported
            interactive: page.cardSupported
            onClicked: page.window.openPage("NvidiaPage.qml", {})
        }
        Repeater {
            model: page.installed
            delegate: ItemRow {}
        }
    }

    Group {
        title: i18n("More")
        visible: page.optional.length > 0

        Repeater {
            model: page.optional
            delegate: ItemRow {}
        }
    }

    Group {
        title: i18n("No driver found")
        note: i18n("Kernora has nothing to offer for these yet. Save a report on the Devices page if you need help.")
        visible: page.missing.length > 0

        Repeater {
            model: page.missing
            delegate: ListItem {
                required property var modelData
                title: modelData.name.length > 0 ? modelData.name : i18n("Unknown device")
                subtitle: modelData.vendorId + ":" + modelData.deviceId
                icon: "dialog-warning"
                iconStyle: "plain"
                chevron: true
                onClicked: page.window.openPage("DevicePage.qml", {device: modelData})
            }
        }
    }

    component ItemRow: ListItem {
        id: row

        required property var modelData
        readonly property bool available: modelData.state === "available"
        readonly property bool canInstall: available && modelData.blocked.length === 0

        title: page.window.pick(modelData.name)
        subtitle: page.detail(modelData)
        icon: modelData.icon
        accent: 1
        interactive: false
        trailing: Component {
            RowLayout {
                spacing: 8
                MButton {
                    visible: row.canInstall
                    enabled: !page.window.busy
                    variant: "tonal"
                    text: i18n("Install")
                    onClicked: page.askInstall(row.modelData)
                }
                MButton {
                    visible: !row.available && row.modelData.open.length > 0
                    variant: "tonal"
                    text: i18n("Open")
                    onClicked: Process.openModule(row.modelData.open)
                }
                MButton {
                    visible: !row.available && row.modelData.removable && !page.window.live
                    enabled: !page.window.busy
                    variant: "text"
                    text: i18n("Remove")
                    onClicked: page.askRemove(row.modelData)
                }
            }
        }
    }

    Dialog {
        id: confirm

        property var item: ({})
        property bool removing: false
        readonly property string name: page.window.pick(item.name)

        title: removing ? i18n("Remove %1?", name) : i18n("Install %1?", name)
        destructive: removing
        acceptText: removing ? i18n("Remove") : i18n("Install")
        text: {
            if (removing) {
                return item.restart ? i18n("You can install it again later. A restart finishes the removal.")
                                    : i18n("You can install it again later.");
            }
            if (item.nonFree) {
                return item.restart ? i18n("This driver isn't open source. You'll need to restart to use it.")
                                    : i18n("This driver isn't open source.");
            }
            return item.restart ? i18n("You'll need to restart to use it.")
                                : i18n("It's downloaded from Debian, the system Kernora is built on.");
        }
        onAccepted: page.window.request(removing ? "drop" : "add", item.id, name)
    }
}
