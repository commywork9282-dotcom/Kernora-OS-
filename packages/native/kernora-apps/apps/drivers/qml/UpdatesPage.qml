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
    property bool active: false
    readonly property int nothingToDo: 2

    property var firmware: []
    property bool firmwareChecking: false
    property bool firmwareFailed: false
    property bool checked: false

    readonly property bool checking: Updates.state === Updates.Checking
    readonly property bool installing: Updates.state === Updates.Installing
    readonly property var fwupd: window.items.find(item => item.id === "firmware-updates") || null
    readonly property bool firmwareOn: fwupd !== null && fwupd.state === "installed"
    readonly property var groups: {
        const result = [];
        const seen = {};
        for (const group of window.hardware.updates || []) {
            const pattern = new RegExp(group.pattern);
            const names = [];
            for (const update of Updates.packages) {
                if (!seen[update.name] && pattern.test(update.name)) {
                    seen[update.name] = true;
                    names.push(update.name);
                }
            }
            if (names.length > 0) {
                result.push({id: group.id, icon: group.icon, name: group.name, packages: names});
            }
        }
        return result;
    }
    readonly property var packages: groups.reduce((list, group) => list.concat(group.packages), [])
    readonly property int total: packages.length + firmware.length

    title: i18n("Updates")
    maximumContentWidth: 720
    subtitle: {
        if (installing) {
            return Updates.status.length > 0 ? Updates.status : i18n("Installing…");
        }
        if (checking || firmwareChecking) {
            return i18n("Checking for updates…");
        }
        if (!checked) {
            return "";
        }
        if (total > 0) {
            return i18np("%1 update available", "%1 updates available", total);
        }
        return firmwareFailed || Updates.error.length > 0 ? "" : i18n("Your drivers are up to date");
    }

    function readFirmware(): void {
        Process.run("fwupdmgr", ["get-updates", "--json"], (code, output) => {
            page.firmwareChecking = false;
            const updates = [];
            try {
                for (const device of JSON.parse(output).Devices || []) {
                    const release = (device.Releases || [])[0];
                    if (release) {
                        updates.push({id: device.DeviceId, name: device.Name, from: device.Version, to: release.Version});
                    }
                }
            } catch (error) {
                page.firmwareFailed = true;
            }
            page.firmware = updates;
        });
    }

    function loadFirmware(): void {
        page.firmwareFailed = false;
        if (!page.firmwareOn) {
            page.firmware = [];
            return;
        }
        page.firmwareChecking = true;
        Process.run("fwupdmgr", ["refresh"], code => {
            page.firmwareFailed = code !== 0 && code !== page.nothingToDo;
            page.readFirmware();
        });
    }

    function check(): void {
        page.checked = true;
        Updates.check();
        page.loadFirmware();
    }

    onActiveChanged: {
        if (active && !checked) {
            check();
        }
    }
    onFirmwareOnChanged: {
        if (checked) {
            loadFirmware();
        }
    }

    Connections {
        target: page.window
        function onJobChanged(): void {
            if (page.window.job.action === "flash" && page.window.job.state === "done") {
                page.loadFirmware();
            }
        }
    }

    actions: Component {
        MButton {
            enabled: !page.checking && !page.installing && !page.firmwareChecking
            variant: "tonal"
            text: i18n("Check")
            onClicked: page.check()
        }
    }

    Banner {
        visible: page.window.restartNeeded
        icon: "system-reboot"
        title: i18n("Restart to finish")
        text: i18n("Your changes start working after a restart.")
        actionText: i18n("Restart")
        onActionTriggered: page.window.restart()
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
        visible: !page.checking && !page.installing && Updates.error.length > 0
        tone: "warning"
        icon: "dialog-warning"
        title: i18n("Updates didn't finish")
        text: Updates.error
    }

    LinearProgress {
        width: parent.width
        visible: page.installing
        indeterminate: Updates.progress <= 0
        value: Updates.progress / 100
    }

    Group {
        title: i18n("Drivers")
        visible: page.groups.length > 0

        Repeater {
            model: page.groups
            delegate: ListItem {
                required property var modelData
                title: page.window.pick(modelData.name)
                subtitle: i18np("%1 package", "%1 packages", modelData.packages.length)
                icon: modelData.icon
                accent: 1
                interactive: false
            }
        }
    }

    RowLayout {
        width: parent.width
        visible: page.groups.length > 0
        Item {
            Layout.fillWidth: true
        }
        MButton {
            enabled: !page.installing && !page.window.busy
            text: i18n("Update drivers")
            onClicked: Updates.install(page.packages)
        }
    }

    Group {
        title: i18n("Firmware")
        visible: page.fwupd !== null
        note: page.firmwareOn ? i18n("Firmware comes from your device's maker through LVFS.") : ""

        ListItem {
            visible: !page.firmwareOn
            title: page.window.pick(page.fwupd ? page.fwupd.name : null)
            subtitle: page.window.pick(page.fwupd ? page.fwupd.text : null)
            icon: "system-software-update"
            accent: 1
            interactive: false
            trailing: Component {
                MButton {
                    visible: page.fwupd !== null && page.fwupd.blocked.length === 0
                    enabled: !page.window.busy
                    variant: "tonal"
                    text: i18n("Turn on")
                    onClicked: page.window.request("add", "firmware-updates", page.window.pick(page.fwupd.name))
                }
            }
        }
        ListItem {
            visible: page.firmwareOn && page.firmware.length === 0
            title: page.firmwareChecking ? i18n("Checking for updates…")
                 : page.firmwareFailed ? i18n("Couldn't check for firmware updates") : i18n("Firmware is up to date")
            subtitle: page.firmwareFailed && !page.firmwareChecking ? i18n("Check the internet connection and try again.") : ""
            icon: page.firmwareFailed ? "dialog-warning" : "dialog-positive"
            iconStyle: "plain"
            interactive: false
        }
        Repeater {
            model: page.firmware
            delegate: ListItem {
                id: row
                required property var modelData
                title: modelData.name
                subtitle: i18nc("firmware version change", "%1 → %2", modelData.from, modelData.to)
                icon: "system-software-update"
                accent: 1
                interactive: false
                trailing: Component {
                    MButton {
                        enabled: !page.window.busy
                        variant: "tonal"
                        text: i18n("Update")
                        onClicked: {
                            flash.device = row.modelData;
                            flash.open();
                        }
                    }
                }
            }
        }
    }

    Dialog {
        id: flash

        property var device: ({})

        title: i18n("Update %1?", device.name || "")
        text: i18n("Keep the computer plugged in and don't turn it off. It may restart during the update.")
        acceptText: i18n("Update")
        onAccepted: page.window.request("flash", device.id, device.name)
    }
}
