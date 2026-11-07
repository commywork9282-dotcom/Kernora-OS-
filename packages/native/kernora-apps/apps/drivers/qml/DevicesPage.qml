/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import org.kernora.m3
import org.kernora.ui
import org.kernora.system

Page {
    id: page

    required property var window
    property bool system: false

    readonly property var labels: ({
        graphics: i18n("Graphics"),
        wifi: i18n("Wi-Fi"),
        network: i18n("Network"),
        bluetooth: i18n("Bluetooth"),
        audio: i18n("Sound"),
        camera: i18n("Cameras"),
        printer: i18n("Printers"),
        storage: i18n("Storage"),
        input: i18n("Input devices"),
        usb: i18n("USB controllers"),
        processor: i18n("Processor"),
        other: i18n("Other"),
        system: i18n("System devices")
    })
    readonly property var icons: ({
        graphics: "video-card",
        wifi: "network-wireless",
        network: "network-wired",
        bluetooth: "bluetooth",
        audio: "audio-card",
        camera: "camera-web",
        printer: "printer",
        storage: "drive-harddisk",
        input: "input-mouse",
        usb: "drive-removable-media-usb",
        processor: "cpu",
        other: "kernora-devices",
        system: "kernora-drivers"
    })
    readonly property var systemDevices: window.devices.filter(device => device.category === "system")
    readonly property var groups: {
        const result = [];
        for (const device of window.devices) {
            if ((device.category === "system") !== page.system) {
                continue;
            }
            let group = result.find(entry => entry.category === device.category);
            if (!group) {
                group = {category: device.category, devices: []};
                result.push(group);
            }
            group.devices.push(device);
        }
        return result;
    }

    title: system ? i18n("System devices") : i18n("Devices")
    subtitle: {
        const name = [window.machine.vendor || "", window.machine.product || ""].join(" ").trim();
        return system ? "" : name;
    }
    maximumContentWidth: 720
    canGoBack: system
    onBack: window.goBack()

    function status(device: var): string {
        switch (device.status) {
        case "none":
            return i18n("No driver");
        case "firmware":
            return i18n("Needs firmware");
        }
        if (device.bus === "cpu") {
            return (device.microcode || "").length > 0 ? i18n("Microcode %1", device.microcode) : "";
        }
        return device.driver.length > 0 ? i18n("Driver: %1", device.driver) : "";
    }

    function saveReport(): void {
        Process.run(page.window.scanner, ["report"], (code, output) => {
            const path = Files.uniqueName(Files.standardFolder("downloads"), "kernora-hardware-report.txt");
            const url = "file://" + path.split("/").map(encodeURIComponent).join("/");
            if (code === 0 && Files.writeText(url, output)) {
                page.window.showMessage(i18n("Report saved to Downloads"), i18n("Open"), () => Process.openUrl(url));
            } else {
                page.window.showMessage(i18n("Couldn't save the report"), "", null);
            }
        });
    }

    actions: Component {
        MButton {
            visible: !page.system
            variant: "tonal"
            text: i18n("Save report")
            onClicked: page.saveReport()
        }
    }

    Repeater {
        model: page.groups
        delegate: Group {
            id: section
            required property var modelData
            title: page.system ? "" : page.labels[modelData.category]

            Repeater {
                model: section.modelData.devices
                delegate: ListItem {
                    required property var modelData
                    title: modelData.name.length > 0 ? modelData.name : i18n("Unknown device")
                    subtitle: page.status(modelData)
                    icon: modelData.status === "none" || modelData.status === "firmware"
                          ? "dialog-warning" : page.icons[modelData.category]
                    iconStyle: "plain"
                    chevron: true
                    onClicked: page.window.openPage("DevicePage.qml", {device: modelData})
                }
            }
        }
    }

    Group {
        visible: !page.system && page.systemDevices.length > 0

        ListItem {
            title: i18n("System devices")
            subtitle: i18np("%1 device", "%1 devices", page.systemDevices.length)
            icon: "kernora-drivers"
            iconStyle: "plain"
            chevron: true
            onClicked: page.window.openPage("DevicesPage.qml", {system: true})
        }
    }
}
