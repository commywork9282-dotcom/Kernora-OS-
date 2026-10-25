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

    title: i18n("System")

    property var timezone: ""
    readonly property bool updating: Updates.state === Updates.Checking || Updates.state === Updates.Installing
    readonly property string channelTool: "/usr/libexec/kernora-update-channel"
    property string channel: ""
    property bool channelBusy: false
    property bool channelWanted: false
    readonly property bool demo: channel === "demo"

    function readChannel(done: var): void {
        Process.run(page.channelTool, ["status"], (code, output) => {
            page.channel = code === 0 ? output.trim() : "";
            if (done) {
                done();
            }
        });
    }

    function setDemo(on: bool): void {
        page.channelWanted = on;
        page.channelBusy = true;
        Process.run("pkexec", [page.channelTool, "set", on ? "demo" : "stable"], code => {
            page.readChannel(() => {
                page.channelBusy = false;
                if (code === 0 && Updates.available && !page.updating) {
                    Updates.check();
                }
            });
        });
    }

    Component.onCompleted: {
        DBus.getProperty("system", "org.freedesktop.timedate1", "/org/freedesktop/timedate1", "org.freedesktop.timedate1", "Timezone",
                         (ok, value) => page.timezone = ok ? value : "");
        if (!SystemInfo.live) {
            readChannel(null);
        }
    }

    ConfigEntry { id: loginMode; file: "ksmserverrc"; group: "General"; key: "loginMode"; defaultValue: "emptySession" }

    Group {
        ListItem {
            title: i18n("Language & region")
            subtitle: Locales.languageName(Locales.language) + " · " + Locales.regionName(Locales.region)
            icon: "preferences-desktop-locale"
            accent: 3
            chevron: true
            onClicked: page.open("LanguagePage.qml", {})
        }
        ListItem {
            title: i18n("Date & time")
            subtitle: String(page.timezone).replace(/_/g, " ")
            icon: "preferences-system-time"
            accent: 3
            chevron: true
            onClicked: page.open("DateTimePage.qml", {})
        }
        ListItem {
            title: i18n("Software updates")
            subtitle: Updates.state === Updates.UpdatesAvailable
                ? i18np("%1 update available", "%1 updates available", Updates.packages.length)
                : i18n("Security fixes and new versions")
            icon: "system-software-update"
            accent: 1
            chevron: true
            onClicked: page.open("UpdatesPage.qml", {})
        }
        ListItem {
            visible: !SystemInfo.live
            title: i18n("Drivers")
            subtitle: i18n("Graphics card drivers")
            icon: "cpu"
            accent: 1
            chevron: true
            onClicked: page.open("DriversPage.qml", {})
        }
        ListItem {
            title: i18n("Storage")
            subtitle: i18n("Free space, trash")
            icon: "drive-harddisk"
            accent: 1
            chevron: true
            onClicked: page.open("StoragePage.qml", {})
        }
    }

    Group {
        title: i18n("Early access")
        visible: !SystemInfo.live && page.channel.length > 0

        ListItem {
            title: i18n("Demo updates")
            subtitle: page.demo
                ? i18n("You get new versions before everyone else. If you turn this off, you keep them until a normal update replaces them")
                : i18n("Get new versions before everyone else. They are still being tested and can have bugs")
            icon: "preferences-system-splash"
            iconStyle: "plain"
            checkable: true
            checked: page.channelBusy ? page.channelWanted : page.demo
            enabled: !page.channelBusy && !page.updating
            onToggled: on => page.setDemo(on)
        }
    }

    Group {
        title: i18n("Session")

        ChoiceItem {
            title: i18n("When you log in")
            icon: "system-run"
            iconStyle: "plain"
            options: [
                { value: "emptySession", label: i18n("Start with an empty desktop") },
                { value: "restorePreviousLogout", label: i18n("Reopen the apps that were open") }
            ]
            currentValue: loginMode.value === "restoreSavedSession" ? "restorePreviousLogout" : loginMode.value
            onSelected: value => loginMode.value = value
        }
    }

    Group {
        title: i18n("More")

        ListItem {
            title: i18n("More settings")
            subtitle: i18n("Printers, shortcuts, fonts and every other option")
            icon: "preferences-other"
            iconStyle: "plain"
            chevron: true
            onClicked: page.open("ModulesPage.qml", {})
        }
        ListItem {
            title: i18n("About Kernora")
            icon: "help-about"
            iconStyle: "plain"
            chevron: true
            onClicked: page.app.openCategory("about", "", {})
        }
    }
}
