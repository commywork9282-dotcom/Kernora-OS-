/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import org.kernora.m3
import org.kernora.ui

Page {
    id: page

    required property var window
    required property var device

    readonly property var rows: {
        const list = [];
        const add = (label, value) => {
            if (value && String(value).length > 0) {
                list.push({label: label, value: String(value)});
            }
        };
        add(i18n("Maker"), device.vendor);
        add(i18n("Driver"), device.driver);
        add(i18n("Driver version"), device.version);
        add(i18n("Microcode"), device.microcode);
        add(i18n("Kernel module"), device.module);
        add(i18n("Hardware ID"), device.vendorId ? device.vendorId + ":" + device.deviceId : "");
        add(i18n("Connected to"), device.bus === "pci" ? "PCI " + device.address : device.bus === "usb" ? "USB " + device.address : "");
        add(i18n("USB speed"), device.speed ? i18n("%1 Mbit/s", device.speed) : "");
        return list;
    }

    title: device.name.length > 0 ? device.name : i18n("Unknown device")
    subtitle: {
        switch (device.status) {
        case "none":
            return i18n("No driver is using this device");
        case "firmware":
            return i18n("This device needs firmware to work");
        }
        return device.driver.length > 0 ? i18n("Working") : "";
    }
    canGoBack: true
    maximumContentWidth: 720
    onBack: window.goBack()

    Banner {
        visible: page.device.status === "firmware" || (page.device.offer || "").length > 0
        tone: page.device.status === "firmware" ? "warning" : "info"
        icon: page.device.status === "firmware" ? "dialog-warning" : "kernora-drivers"
        title: page.device.status === "firmware" ? i18n("Firmware is missing") : i18n("A driver is available")
        text: (page.device.firmware || []).join("\n")
        actionText: i18n("Go to Drivers")
        onActionTriggered: {
            page.window.tab = "drivers";
            page.window.goBack();
        }
    }

    Group {
        Repeater {
            model: page.rows
            delegate: ListItem {
                required property var modelData
                title: modelData.label
                subtitle: modelData.value
                interactive: false
            }
        }
    }
}
