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

    title: i18n("About Kernora")

    property string deviceName: ""

    function loadName(): void {
        DBus.getAllProperties("system", "org.freedesktop.hostname1", "/org/freedesktop/hostname1", "org.freedesktop.hostname1", (ok, props) => {
            if (ok) {
                page.deviceName = props.PrettyHostname || props.StaticHostname || props.Hostname || SystemInfo.hostname;
            }
        });
    }
    Component.onCompleted: loadName()

    function setDeviceName(name: string): void {
        const host = name.normalize("NFKD").toLowerCase().replace(/[^a-z0-9-]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 63) || "kernora";
        const service = "org.freedesktop.hostname1";
        DBus.call("system", service, "/org/freedesktop/hostname1", service, "SetPrettyHostname",
                  [{ type: "s", value: name }, { type: "b", value: true }], ok => {
            if (!ok) {
                page.notify(i18n("The name could not be changed."));
                return;
            }
            DBus.call("system", service, "/org/freedesktop/hostname1", service, "SetStaticHostname",
                      [{ type: "s", value: host }, { type: "b", value: true }], () => page.loadName(), true);
        }, true);
    }

    readonly property string versionText: {
        const codename = SystemInfo.osCodename;
        const named = codename && SystemInfo.osVersion.toLowerCase().includes(codename.toLowerCase());
        return named || !codename ? SystemInfo.osVersion
            : SystemInfo.osVersion + " (" + codename.charAt(0).toUpperCase() + codename.slice(1) + ")";
    }

    readonly property string summary: [
        SystemInfo.osName + " " + page.versionText,
        i18n("Based on Debian %1", SystemInfo.osBase),
        i18n("Processor: %1", SystemInfo.cpu),
        i18n("Memory: %1", SystemInfo.formatBytes(SystemInfo.memoryBytes)),
        i18n("Graphics: %1", SystemInfo.graphics),
        i18n("Kernel: %1", SystemInfo.kernel),
        i18n("Desktop: KDE Plasma %1, Frameworks %2, Qt %3", SystemInfo.plasmaVersion, SystemInfo.frameworksVersion, SystemInfo.qtVersion)
    ].join("\n")

    hero: Component {
        Rectangle {
            width: parent ? parent.width : 0
            implicitHeight: heroColumn.implicitHeight + 64
            radius: M3.classic ? M3.cornerCard : 28
            color: M3.primaryContainer

            ColumnLayout {
                id: heroColumn
                anchors.centerIn: parent
                width: parent.width - 48
                spacing: 8

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 104
                    implicitHeight: 104
                    radius: 52
                    color: M3.primary
                    MIcon {
                        anchors.centerIn: parent
                        size: 68
                        source: "kernora-logo"
                        color: M3.primaryContent
                    }
                }
                MText {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    role: "displaySmall"
                    text: SystemInfo.osName
                    horizontalAlignment: Text.AlignHCenter
                    color: M3.primaryContainerContent
                }
                MText {
                    Layout.fillWidth: true
                    role: "titleMedium"
                    text: i18n("Version %1", page.versionText)
                    horizontalAlignment: Text.AlignHCenter
                    color: M3.primaryContainerContent
                }
                MText {
                    Layout.fillWidth: true
                    role: "bodyMedium"
                    visible: SystemInfo.live
                    text: i18n("Running from the installation medium")
                    horizontalAlignment: Text.AlignHCenter
                    color: M3.primaryContainerContent
                    opacity: 0.8
                }
            }
        }
    }

    Group {
        title: i18n("This computer")

        ListItem {
            title: i18n("Device name")
            subtitle: page.deviceName
            icon: "computer"
            accent: 0
            chevron: true
            onClicked: nameDialog.open()
        }
        ListItem {
            title: i18n("Model")
            visible: SystemInfo.product.length > 0
            interactive: false
            subtitle: (SystemInfo.vendor + " " + SystemInfo.product).trim()
            icon: SystemInfo.chassis === "laptop" ? "computer-laptop" : "computer"
            iconStyle: "plain"
        }
        ListItem {
            title: i18n("Processor")
            interactive: false
            subtitle: i18np("%2, %1 thread", "%2, %1 threads", SystemInfo.cpuThreads, SystemInfo.cpu)
            icon: "cpu"
            iconStyle: "plain"
        }
        ListItem {
            title: i18n("Memory")
            interactive: false
            subtitle: i18n("%1, %2 available", SystemInfo.formatBytes(SystemInfo.memoryBytes), SystemInfo.formatBytes(SystemInfo.memoryAvailable()))
            icon: "memory"
            iconStyle: "plain"
        }
        ListItem {
            title: i18n("Graphics")
            interactive: false
            subtitle: SystemInfo.graphics
            icon: "video-display"
            iconStyle: "plain"
        }
    }

    Group {
        title: i18n("Software")

        ListItem { interactive: false; title: SystemInfo.osName; value: page.versionText; icon: "kernora-logo"; iconStyle: "plain" }
        ListItem { interactive: false; title: i18n("Based on"); value: i18n("Debian %1", SystemInfo.osBase); icon: "package-x-generic"; iconStyle: "plain" }
        ListItem { interactive: false; title: i18n("Kernel"); value: SystemInfo.kernel; icon: "deployed-code"; iconStyle: "plain" }
        ListItem { interactive: false; title: i18n("KDE Plasma"); value: SystemInfo.plasmaVersion; icon: "plasma"; iconStyle: "plain" }
        ListItem { interactive: false; title: i18n("KDE Frameworks"); value: SystemInfo.frameworksVersion; icon: "applications-plugin"; iconStyle: "plain" }
        ListItem { interactive: false; title: i18n("Qt"); value: SystemInfo.qtVersion; icon: "applications-development"; iconStyle: "plain" }
        ListItem { interactive: false; title: i18n("Graphics platform"); value: SystemInfo.windowingSystem; icon: "window"; iconStyle: "plain" }
    }

    Group {
        ListItem {
            title: i18n("Legal information")
            subtitle: i18n("Licences, authors and copyrights of the software in Kernora")
            icon: "help-about"
            accent: 0
            chevron: true
            onClicked: page.open("LegalPage.qml", {})
        }
        ListItem {
            title: i18n("Copy system details")
            subtitle: i18n("For a bug report or a support request")
            icon: "edit-copy"
            iconStyle: "plain"
            onClicked: {
                clipboard.text = page.summary;
                clipboard.selectAll();
                clipboard.copy();
                page.notify(i18n("System details copied."));
            }
        }
    }

    TextEdit {
        id: clipboard
        visible: false
    }

    Dialog {
        id: nameDialog
        title: i18n("Device name")
        text: i18n("Other devices on the network and Bluetooth see this computer by this name.")
        acceptText: i18n("Rename")
        acceptEnabled: nameField.text.trim().length > 0
        onOpened: {
            nameField.text = page.deviceName;
            nameField.forceActiveFocus();
        }
        onAccepted: page.setDeviceName(nameField.text.trim())
        InputField {
            id: nameField
            Layout.fillWidth: true
            label: i18n("Name")
            onAccepted: {
                if (nameDialog.acceptEnabled) {
                    nameDialog.accept();
                }
            }
        }
    }
}
