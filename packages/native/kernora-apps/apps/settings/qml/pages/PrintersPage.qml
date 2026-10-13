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
import "../components"

SettingsPage {
    id: page

    title: i18n("Printers & scanners")
    subtitle: i18n("Printers on your network and USB printers are found by themselves. Most need no driver.")

    property var printers: []
    property string defaultPrinter: ""
    property bool loaded: false
    property string busy: ""

    readonly property string addTool: Process.findExecutable("kde-add-printer")
    readonly property bool canScan: Process.application("org.kde.skanpage.desktop").name !== undefined

    function refresh(): void {
        Process.run("env", ["LC_ALL=C", "lpstat", "-d", "-p"], (code, output) => {
            const found = [];
            let fallback = "";
            for (const line of output.split("\n")) {
                const printer = line.match(/^printer (\S+) (?:is )?(idle|now printing|disabled)/);
                if (printer) {
                    found.push({ name: printer[1], state: printer[2] });
                }
                const chosen = line.match(/^system default destination: (\S+)/);
                if (chosen) {
                    fallback = chosen[1];
                }
            }
            page.printers = found;
            page.defaultPrinter = fallback;
            page.loaded = true;
        });
    }

    function stateText(printer: var): string {
        const parts = [];
        if (printer.name === defaultPrinter) {
            parts.push(i18n("Default"));
        }
        parts.push(printer.state === "now printing" ? i18n("Printing")
            : printer.state === "disabled" ? i18n("Paused") : i18n("Ready"));
        return parts.join(" · ");
    }

    function makeDefault(name: string): void {
        Process.run("lpoptions", ["-d", name], code => {
            page.notify(code === 0 ? i18n("%1 is now the default printer", name) : i18n("Couldn't change the default printer"));
            page.refresh();
        });
    }

    function testPage(name: string): void {
        busy = name;
        Process.run("lp", ["-d", name, "/usr/share/cups/data/testprint"], code => {
            page.busy = "";
            page.notify(code === 0 ? i18n("Test page sent to %1", name) : i18n("Couldn't print a test page"));
        });
    }

    function addPrinter(): void {
        if (addTool.length > 0) {
            Process.startDetached(addTool, ["--add-printer"]);
        } else {
            Process.openModule("kcm_printer_manager");
        }
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 5000
        running: page.visible
        repeat: true
        onTriggered: page.refresh()
    }

    Group {
        title: i18n("Printers")
        note: !page.loaded ? i18n("Looking for printers…")
            : page.printers.length === 0 ? i18n("No printers yet. Turn your printer on and connect it to the same network or with a USB cable.") : ""

        Repeater {
            model: page.printers
            delegate: ListItem {
                id: printerRow
                required property var modelData
                title: modelData.name.replace(/_/g, " ")
                subtitle: page.stateText(modelData)
                icon: "printer"
                accent: modelData.name === page.defaultPrinter ? 0 : -1
                iconStyle: modelData.name === page.defaultPrinter ? "circle" : "plain"
                trailing: Component {
                    RowLayout {
                        spacing: 4
                        QQC2.BusyIndicator {
                            visible: page.busy === printerRow.modelData.name
                            running: visible
                            implicitWidth: 24
                            implicitHeight: 24
                        }
                        QQC2.Button {
                            text: i18n("Test page")
                            flat: true
                            enabled: page.busy.length === 0
                            onClicked: page.testPage(printerRow.modelData.name)
                        }
                    }
                }
                onClicked: {
                    if (modelData.name !== page.defaultPrinter) {
                        page.makeDefault(modelData.name);
                    }
                }
            }
        }

        ListItem {
            title: i18n("Add a printer")
            subtitle: i18n("For a printer that isn't found by itself")
            icon: "list-add"
            accent: 2
            chevron: true
            onClicked: page.addPrinter()
        }
    }

    Group {
        title: i18n("Scanners")

        ListItem {
            title: i18n("Scan a document")
            subtitle: page.canScan ? i18n("Scanners on the network and USB scanners work without drivers")
                : i18n("The scanning app is not installed")
            icon: "printer"
            accent: 1
            chevron: true
            enabled: page.canScan
            onClicked: Process.launchApplication("org.kde.skanpage.desktop", [])
        }
    }

    Group {
        ListItem {
            title: i18n("Print queue and advanced options")
            subtitle: i18n("Jobs, paper, drivers, sharing")
            icon: "applications-system"
            chevron: true
            onClicked: Process.openModule("kcm_printer_manager")
        }
    }
}
