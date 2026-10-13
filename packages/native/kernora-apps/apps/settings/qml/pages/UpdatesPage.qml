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

    title: i18n("Software updates")

    readonly property int state: Updates.state
    readonly property bool working: state === Updates.Checking || state === Updates.Installing

    Component.onCompleted: {
        if (!SystemInfo.live && Updates.available && state === Updates.Idle) {
            Updates.check();
        }
    }

    readonly property string headline: {
        switch (state) {
        case Updates.Checking: return i18n("Checking for updates…");
        case Updates.UpToDate: return i18n("Your system is up to date");
        case Updates.UpdatesAvailable: return i18np("%1 update is available", "%1 updates are available", Updates.packages.length);
        case Updates.Installing: return i18n("Installing updates…");
        case Updates.Installed: return i18n("Updates are installed");
        case Updates.Failed: return i18n("Updating did not work");
        }
        return i18n("Software updates");
    }
    readonly property string detail: {
        if (!Updates.available) {
            return i18n("The update service is not available.");
        }
        if (state === Updates.Failed) {
            return Updates.error;
        }
        if (working) {
            return Updates.status;
        }
        if (state === Updates.Installed && Updates.restartNeeded) {
            return i18n("Restart the computer to finish.");
        }
        if (Updates.lastCheck > 0) {
            return i18n("Last checked %1", new Date(Updates.lastCheck).toLocaleString(Qt.locale(), Locale.ShortFormat));
        }
        return "";
    }

    Rectangle {
        id: liveCard
        visible: SystemInfo.live
        width: parent.width
        implicitHeight: liveContent.implicitHeight + 48
        radius: M3.classic ? M3.cornerCard : 28
        color: M3.surfaceContainerHigh

        ColumnLayout {
            id: liveContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: 24
            spacing: 16

            RowLayout {
                spacing: 16
                IconCircle {
                    size: 56
                    icon: "system-software-install"
                    accent: 1
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    MText {
                        Layout.fillWidth: true
                        role: "titleLarge"
                        text: i18n("Updates come with the installation")
                        wrapMode: Text.Wrap
                    }
                    MText {
                        Layout.fillWidth: true
                        role: "bodyMedium"
                        text: i18n("You are trying Lumo from the installation medium, and nothing installed here is kept. Install Lumo: when the computer is online, the installer brings the new system up to date by itself.")
                        wrapMode: Text.Wrap
                        color: M3.surfaceVariantContent
                    }
                }
            }
            QQC2.Button {
                text: i18n("Install Lumo")
                icon.name: "system-software-install"
                highlighted: true
                onClicked: Process.launchApplication("org.kernora.installer.desktop", [])
            }
        }
    }

    Rectangle {
        id: card
        visible: !SystemInfo.live
        width: parent.width
        implicitHeight: status.implicitHeight + 48
        radius: M3.classic ? M3.cornerCard : 28
        color: page.state === Updates.UpdatesAvailable ? M3.tertiaryContainer
             : page.state === Updates.Failed ? M3.errorContainer : M3.surfaceContainerHigh

        readonly property color ink: page.state === Updates.UpdatesAvailable ? M3.tertiaryContainerContent
             : page.state === Updates.Failed ? M3.errorContainerContent : M3.surfaceContent

        ColumnLayout {
            id: status
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: 24
            spacing: 12

            RowLayout {
                spacing: 16
                IconCircle {
                    size: 56
                    icon: page.state === Updates.UpToDate || page.state === Updates.Installed ? "dialog-positive"
                        : page.state === Updates.Failed ? "dialog-error" : "system-software-update"
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
                        color: card.ink
                    }
                    MText {
                        Layout.fillWidth: true
                        role: "bodyMedium"
                        text: page.detail
                        visible: text.length > 0
                        wrapMode: Text.Wrap
                        color: card.ink
                    }
                }
            }
            LinearProgress {
                Layout.fillWidth: true
                visible: page.working
                indeterminate: Updates.progress <= 0 || Updates.progress > 100
                value: Updates.progress / 100
            }
            RowLayout {
                spacing: 8
                visible: !page.working && Updates.available
                QQC2.Button {
                    visible: page.state === Updates.UpdatesAvailable
                    text: i18n("Install now")
                    icon.name: "system-software-update"
                    highlighted: true
                    onClicked: Updates.install()
                }
                QQC2.Button {
                    visible: page.state === Updates.Installed && Updates.restartNeeded
                    text: i18n("Restart")
                    icon.name: "system-reboot"
                    highlighted: true
                    onClicked: DBus.call("session", "org.kde.LogoutPrompt", "/LogoutPrompt", "org.kde.LogoutPrompt", "promptReboot", [], null)
                }
                QQC2.Button {
                    text: i18n("Check again")
                    icon.name: "view-refresh"
                    flat: page.state === Updates.UpdatesAvailable
                    onClicked: Updates.check()
                }
            }
        }
    }

    Group {
        title: i18n("What changes")
        visible: page.state === Updates.UpdatesAvailable && Updates.packages.length > 0

        Repeater {
            model: page.state === Updates.UpdatesAvailable ? Updates.packages : []
            delegate: ListItem {
                required property var modelData
                interactive: false
                title: modelData.name
                subtitle: modelData.summary || ""
                value: modelData.version
                icon: modelData.security ? "security-high" : "package-x-generic"
                accent: modelData.security ? 4 : -1
                iconStyle: modelData.security ? "circle" : "plain"
                maximumSubtitleLines: 1
            }
        }
    }
}
