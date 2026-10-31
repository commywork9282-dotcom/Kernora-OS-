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

    title: i18n("Android apps")

    readonly property string tool: "/usr/libexec/kernora-android"
    property var info: ({})
    property bool loaded: false
    property string choice: "vanilla"
    property bool actionFailed: false
    property bool starting: false
    property real requestedAt: 0
    property string androidId: ""

    readonly property bool live: info.live === "yes"
    readonly property bool ready: info.ready === "yes" && info.installed === "yes"
    readonly property string status: info.status || ""
    readonly property bool jobRunning: info.job === "yes"
    readonly property bool fresh: Number(info.time || 0) >= requestedAt - 1 && Date.now() / 1000 - requestedAt < 20
    readonly property bool busy: ["installing", "downloading", "unpacking", "removing"].includes(status) && (jobRunning || fresh)
    readonly property bool stalled: ["installing", "downloading", "unpacking", "removing"].includes(status) && !busy
    readonly property bool failed: !busy && (status === "failed" || status === "offline" || stalled || actionFailed)
    readonly property bool google: info.kind === "gapps"
    readonly property int progress: Number(info.progress || 0)

    function refresh(): void {
        Process.run(page.tool, ["status"], (code, output) => {
            const values = {};
            for (const line of output.split("\n")) {
                const at = line.indexOf("=");
                if (at > 0) {
                    values[line.slice(0, at)] = line.slice(at + 1);
                }
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
            }
            page.refresh();
        });
    }

    function size(bytes: real): string {
        return i18n("%1 GB", (bytes / 1073741824).toLocaleString(Qt.locale(), "f", 1));
    }

    Component.onCompleted: refresh()

    Timer {
        interval: page.busy ? 1000 : 5000
        running: page.visible
        repeat: true
        onTriggered: page.refresh()
    }

    readonly property string headline: {
        if (!loaded) {
            return "";
        }
        if (busy) {
            switch (status) {
            case "installing":
                return i18n("Getting Android ready…");
            case "downloading":
                return i18n("Downloading Android… %1%", progress);
            case "unpacking":
                return i18n("Unpacking Android…");
            case "removing":
                return i18n("Removing Android…");
            }
        }
        if (failed) {
            return status === "offline" ? i18n("No internet connection") : i18n("Android couldn't be turned on");
        }
        return "";
    }

    readonly property string detail: {
        if (busy) {
            return status === "removing" ? i18n("Android apps and their data are being deleted from this computer.")
                                         : i18n("This takes a few minutes. You can keep using the computer.");
        }
        if (failed) {
            return status === "offline" ? i18n("Android is downloaded from the internet. Connect to a network and try again.")
                                        : i18n("Check the internet connection and that there is enough free space, then try again.");
        }
        return "";
    }

    Item {
        width: parent.width
        implicitHeight: art.height + blurb.implicitHeight + 36

        MShape {
            id: art
            anchors.horizontalCenter: parent.horizontalCenter
            y: 8
            width: 136
            height: 136
            shape: M3.classic ? "circle" : "cookie9"
            color: page.ready ? M3.primaryContainer : M3.surfaceContainerHighest
            Behavior on color { ColorAnimation { duration: M3.durationMedium2 } }
            RotationAnimator on rotation {
                from: 0
                to: 360
                duration: 24000
                loops: Animation.Infinite
                running: (Android.running || page.busy) && art.visible && M3.motionScale > 0 && !M3.classic
            }
        }
        MIcon {
            anchors.centerIn: art
            size: 64
            source: "kernora-android"
            color: page.ready ? M3.primaryContainerContent : M3.surfaceVariantContent
        }
        MText {
            id: blurb
            anchors.top: art.bottom
            anchors.topMargin: 16
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width, 440)
            horizontalAlignment: Text.AlignHCenter
            role: "bodyMedium"
            color: M3.surfaceVariantContent
            wrapMode: Text.Wrap
            text: page.live ? i18n("Android apps work after Kernora is installed on this computer.")
                            : i18n("Install Android apps from APK files. Each app opens in its own window, next to your other apps.")
        }
    }

    Rectangle {
        id: summary
        visible: page.busy || page.failed
        width: parent.width
        implicitHeight: content.implicitHeight + 48
        radius: M3.classic ? M3.cornerCard : 28
        color: page.failed ? M3.errorContainer : M3.surfaceContainerHigh

        readonly property color ink: page.failed ? M3.errorContainerContent : M3.surfaceContent

        ColumnLayout {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: 24
            spacing: 12

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
            LinearProgress {
                Layout.fillWidth: true
                visible: page.busy
                indeterminate: page.status !== "downloading"
                value: page.progress / 100
            }
            RowLayout {
                spacing: 8
                visible: (page.busy && (page.status === "downloading" || page.status === "unpacking")) || page.failed
                QQC2.Button {
                    visible: page.busy
                    text: i18n("Cancel")
                    flat: true
                    onClicked: page.request("cancel")
                }
                QQC2.Button {
                    visible: page.failed
                    text: i18n("Try again")
                    icon.name: "view-refresh"
                    highlighted: true
                    onClicked: page.request(page.choice === "gapps" ? "setup-gapps" : "setup-vanilla")
                }
            }
        }
    }

    Group {
        title: i18n("Choose Android")
        note: i18n("Google Play asks you to register this computer once before you sign in. Android takes about 3 GB of disk space. Banking apps and games with anti-cheat only run on phones.")
        visible: page.loaded && !page.live && !page.ready && !page.busy

        RadioRow {
            width: parent.width
            title: i18n("Android")
            subtitle: i18n("APK files and open stores like F-Droid · about 1 GB")
            checked: page.choice === "vanilla"
            onClicked: page.choice = "vanilla"
        }
        RadioRow {
            width: parent.width
            title: i18n("Android with Google Play")
            subtitle: i18n("Play Store and Google services · about 1.4 GB")
            checked: page.choice === "gapps"
            onClicked: page.choice = "gapps"
        }
    }

    RowLayout {
        width: parent.width
        visible: page.loaded && !page.live && !page.ready && !page.busy && !page.failed

        Item {
            Layout.fillWidth: true
        }
        QQC2.Button {
            text: i18n("Turn on")
            icon.name: "download"
            highlighted: true
            onClicked: page.request(page.choice === "gapps" ? "setup-gapps" : "setup-vanilla")
        }
    }

    Group {
        visible: page.ready && !page.busy

        ListItem {
            title: i18n("Android")
            subtitle: page.starting ? i18n("Starting…")
                    : Android.running ? i18n("Running")
                    : i18n("Starts by itself when you open an Android app")
            icon: "kernora-android"
            accent: 2
            checkable: true
            checked: Android.running || page.starting
            enabled: !page.starting
            onToggled: on => {
                if (on) {
                    page.starting = true;
                    Android.start(() => page.starting = false);
                } else {
                    Android.stop();
                }
            }
        }
        ListItem {
            title: i18n("Install an app from an APK file")
            icon: "kernora-apk-install"
            iconStyle: "plain"
            chevron: true
            onClicked: Process.startDetached("kernora-apkinstaller", [])
        }
        ListItem {
            title: i18n("Android settings")
            subtitle: i18n("Language, accounts and app permissions inside Android")
            icon: "configure"
            iconStyle: "plain"
            chevron: true
            onClicked: Android.openSettings()
        }
    }

    Group {
        title: i18n("Google Play")
        note: i18n("Before you can sign in to the Play Store, register this computer with Google. Start Android, copy the device ID and paste it on Google's page.")
        visible: page.ready && !page.busy && page.google

        ListItem {
            title: i18n("Register with Google")
            subtitle: page.androidId.length > 0 ? i18n("Device ID: %1", page.androidId) : i18n("Shows the device ID and opens Google's page")
            icon: "kernora-android"
            iconStyle: "plain"
            chevron: true
            enabled: Android.running
            onClicked: Process.run("pkexec", [page.tool, "android-id"], (code, output) => {
                page.androidId = output.trim();
                if (page.androidId.length > 0) {
                    Android.copyText(page.androidId);
                    page.notify(i18n("Device ID copied"));
                    Process.openUrl("https://www.google.com/android/uncertified");
                } else {
                    page.notify(i18n("Open the Play Store once, then try again"));
                }
            })
        }
    }

    Group {
        title: i18n("Apps")
        visible: page.ready && !page.busy && Android.apps.length > 0

        Repeater {
            model: Android.apps

            delegate: ListItem {
                id: row
                required property var modelData
                title: modelData.name
                subtitle: modelData.package
                leading: Component {
                    AppIcon {
                        name: row.modelData.icon
                    }
                }
                trailing: Component {
                    IconButton {
                        iconName: "user-trash"
                        text: i18n("Uninstall")
                        onClicked: Android.uninstall(row.modelData.package)
                    }
                }
                onClicked: Android.launch(modelData.package)
            }
        }
    }

    Group {
        visible: page.ready && !page.busy

        ListItem {
            title: i18n("Storage")
            subtitle: page.google ? i18n("Android with Google Play") : i18n("Android")
            value: page.size(Number(page.info.size || 0))
            icon: "drive-harddisk"
            iconStyle: "plain"
            interactive: false
        }
        ListItem {
            title: i18n("Remove Android")
            subtitle: i18n("Deletes Android, every Android app and its data")
            icon: "edit-delete"
            iconStyle: "plain"
            destructive: true
            onClicked: removeDialog.open()
        }
    }

    Dialog {
        id: removeDialog
        title: i18n("Remove Android?")
        text: i18n("Every Android app and all of its data are deleted from this computer. You can turn Android on again later.")
        acceptText: i18n("Remove")
        destructive: true
        onAccepted: page.request("remove")
    }
}
