/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtCore as Core
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
    readonly property string store: "com.android.vending"
    property var info: ({})
    property bool loaded: false
    property string choice: "gapps"
    property bool actionFailed: false
    property real requestedAt: 0
    property bool faster: false
    property bool googleWorking: false
    property bool reporting: false

    readonly property bool live: info.live === "yes"
    readonly property bool ready: info.ready === "yes" && info.installed === "yes"
    readonly property string status: info.status || ""
    readonly property var working: ["installing", "downloading", "unpacking", "removing", "updating"]
    readonly property bool jobRunning: info.job === "yes"
    readonly property bool fresh: Number(info.time || 0) >= requestedAt - 1 && Date.now() / 1000 - requestedAt < 20
    readonly property bool busy: working.includes(status) && (jobRunning || fresh)
    readonly property bool stalled: working.includes(status) && status !== "updating" && !busy
    readonly property bool failed: !busy && (status === "failed" || status === "offline" || stalled || actionFailed)
    readonly property bool google: info.kind === "gapps"
    readonly property int progress: Number(info.progress || 0)
    readonly property int remaining: (info.remaining || "") === "" ? -1 : Number(info.remaining)
    readonly property real bytes: Number(info.bytes || 0)
    readonly property real bytesTotal: Number(info.bytes_total || 0)
    readonly property bool setupStage: busy && (status === "installing" || status === "downloading" || status === "unpacking")
    readonly property string googleId: info.google_id || ""
    readonly property bool googleSignedIn: Number(info.google_accounts || 0) > 0
    readonly property var userApps: Android.apps.filter(app => app.package !== page.store)

    function refresh(done) {
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
            if (done) {
                done();
            }
        });
        Process.run("systemctl", ["--user", "is-enabled", "kernora-android.service"], (code, output) => {
            page.faster = output.trim() === "enabled";
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

    function saveReport(): void {
        page.reporting = true;
        Process.run("pkexec", [page.tool, "report"], (code, output) => {
            page.reporting = false;
            const path = output.trim().split("\n").pop();
            if (code !== 0 || !path.startsWith("/")) {
                if (code !== 126 && code !== 127) {
                    page.notify(i18n("The report couldn't be saved. Try again."));
                }
                return;
            }
            const at = path.lastIndexOf("/");
            page.notify(i18n("Saved as %1. Send this file to Kernora's developers.", path.slice(at + 1)));
            Process.openUrl("file://" + path.slice(0, at));
        });
    }

    function size(bytes: real): string {
        return bytes >= 1073741824 ? i18n("%1 GB", (bytes / 1073741824).toLocaleString(Qt.locale(), "f", 1))
                                   : i18n("%1 MB", Math.round(bytes / 1048576));
    }

    function registerWithGoogle(): void {
        if (page.googleId.length > 0) {
            Android.copyText(page.googleId);
            Process.openUrl("https://www.google.com/android/uncertified");
            remembered.googleRegistered = true;
            remembered.restartPending = true;
            page.notify(i18n("Code copied. Paste it on Google's page."));
            return;
        }
        page.googleWorking = true;
        Process.run("/usr/libexec/kernora-android-session", ["--google"], () => {
            page.refresh(() => {
                page.googleWorking = false;
                if (page.googleId.length > 0) {
                    page.registerWithGoogle();
                } else {
                    page.notify(i18n("The code isn't ready yet. Try again in a minute."));
                }
            });
        });
    }

    function openStore(): void {
        if (!remembered.restartPending) {
            Android.launch(page.store);
            return;
        }
        remembered.restartPending = false;
        Process.run("systemctl", ["--user", "stop", "kernora-android.service"], () => Android.launch(page.store));
    }

    Core.Settings {
        id: remembered
        category: "AndroidApps"
        property bool googleRegistered: false
        property bool restartPending: false
    }

    Component.onCompleted: refresh()

    Timer {
        interval: page.busy ? 1000 : 5000
        running: page.visible
        repeat: true
        onTriggered: page.refresh()
    }

    readonly property string headline: {
        if (busy) {
            switch (status) {
            case "removing":
                return i18n("Removing Android apps…");
            case "updating":
                return i18n("Updating…");
            case "unpacking":
                return i18n("Almost ready…");
            default:
                return i18n("Setting up Android apps…");
            }
        }
        if (failed) {
            return status === "offline" ? i18n("No internet connection") : i18n("Android apps couldn't be set up");
        }
        return "";
    }

    readonly property string detail: {
        if (busy) {
            switch (status) {
            case "removing":
                return i18n("Every Android app and its data are being deleted from this computer.");
            case "updating":
                return i18n("Android apps are getting an update. They open again once it's done.");
            case "installing":
                return i18n("Getting ready");
            case "downloading": {
                const parts = [];
                if (bytesTotal > 0) {
                    parts.push(i18n("%1 of %2", size(bytes), size(bytesTotal)));
                }
                if (remaining >= 60) {
                    parts.push(i18np("About %1 minute left", "About %1 minutes left", Math.ceil(remaining / 60)));
                } else if (remaining >= 0) {
                    parts.push(i18n("Less than a minute left"));
                }
                return parts.length > 0 ? parts.join(" · ") : i18n("This takes a few minutes");
            }
            default:
                return i18n("This takes a few minutes");
            }
        }
        if (failed) {
            return status === "offline" ? i18n("Everything apps need is downloaded from the internet. Connect to a network and try again.")
                                        : i18n("Check the internet connection and that there is enough free space, then try again.");
        }
        return "";
    }

    component Choice: ListItem {
        id: option

        property string value
        property bool recommended: false
        readonly property bool selected: page.choice === value

        Accessible.role: Accessible.RadioButton
        Accessible.checked: selected
        leading: Component {
            QQC2.RadioButton {
                checked: option.selected
                focusPolicy: Qt.NoFocus
                onClicked: page.choice = option.value
                Accessible.ignored: true
            }
        }
        trailing: Component {
            Rectangle {
                visible: option.recommended
                implicitWidth: badge.implicitWidth + 24
                implicitHeight: 28
                radius: M3.classic ? 4 : 14
                color: M3.tertiaryContainer
                MText {
                    id: badge
                    anchors.centerIn: parent
                    role: "labelLarge"
                    text: i18n("Recommended")
                    color: M3.tertiaryContainerContent
                }
            }
        }
        onClicked: page.choice = value
    }

    Item {
        width: parent.width
        implicitHeight: art.height + blurb.implicitHeight + 36

        MMorph {
            id: readyMorph
            active: page.ready
            dampingRatio: M3.springExpressiveDefaultDamping
            response: M3.springExpressiveDefaultResponse
        }
        MShape {
            id: art
            anchors.horizontalCenter: parent.horizontalCenter
            y: 8
            width: 136
            height: 136
            shape: M3.classic ? "circle" : (page.ready ? "sunny" : "cookie9")
            color: page.ready ? M3.primaryContainer : M3.surfaceContainerHighest
            scale: 0.92 + 0.08 * readyMorph.value
            Behavior on color { ColorAnimation { duration: M3.durationMedium2 } }
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
            text: page.live ? i18n("Android apps work once Kernora is installed on this computer.")
                            : i18n("Apps for phones and tablets, each in its own window.")
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

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                MText {
                    Layout.fillWidth: true
                    role: "titleLarge"
                    text: page.headline
                    wrapMode: Text.Wrap
                    color: summary.ink
                }
                MText {
                    visible: page.setupStage && page.progress > 0
                    role: "titleLarge"
                    text: i18n("%1%", page.progress)
                    color: M3.primary
                }
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
                indeterminate: !page.setupStage || page.progress === 0
                value: page.progress / 100
            }
            RowLayout {
                spacing: 8
                visible: (page.busy && (page.status === "downloading" || page.status === "unpacking")) || page.failed
                MButton {
                    visible: page.busy
                    variant: "text"
                    text: i18n("Cancel")
                    onClicked: page.request("cancel")
                }
                MButton {
                    visible: page.failed
                    text: i18n("Try again")
                    icon: "view-refresh"
                    onClicked: page.request(page.choice === "gapps" ? "setup-gapps" : "setup-vanilla")
                }
            }
        }
    }

    Group {
        title: i18n("Get apps from")
        note: i18n("Needs about 3 GB of space. Banking apps and games with anti-cheat don't work here.")
        visible: page.loaded && !page.live && !page.ready && !page.busy

        Choice {
            value: "gapps"
            recommended: true
            title: i18n("Google Play and APK files")
            subtitle: i18n("Like on an Android phone · about 1.4 GB to download")
        }
        Choice {
            value: "vanilla"
            title: i18n("APK files only")
            subtitle: i18n("No Google services · about 1 GB to download")
        }
    }

    RowLayout {
        width: parent.width
        visible: page.loaded && !page.live && !page.ready && !page.busy && !page.failed

        Item {
            Layout.fillWidth: true
        }
        MButton {
            text: i18n("Set up")
            icon: "download"
            onClicked: page.request(page.choice === "gapps" ? "setup-gapps" : "setup-vanilla")
        }
    }

    Group {
        title: i18n("Finish setting up Google Play")
        note: i18n("Google asks to register computers that run Android apps. You only do this once.")
        visible: page.ready && !page.busy && page.google && !page.googleSignedIn

        ListItem {
            title: i18n("Register this computer")
            subtitle: page.googleWorking ? i18n("Getting the code, this takes a minute the first time…")
                                         : i18n("Opens Google's page with the code copied. Paste it there and press Register.")
            maximumSubtitleLines: 3
            interactive: false
            leading: Component {
                Step {
                    number: 1
                    done: remembered.googleRegistered
                }
            }
            trailing: Component {
                MButton {
                    enabled: !page.googleWorking
                    variant: remembered.googleRegistered ? "tonal" : "filled"
                    text: remembered.googleRegistered ? i18n("Again") : i18n("Register")
                    onClicked: page.registerWithGoogle()
                }
            }
        }
        ListItem {
            title: i18n("Sign in to Google Play")
            subtitle: i18n("Google can take a few minutes to accept the code. If Google Play says this device isn't certified, wait a little and try again.")
            maximumSubtitleLines: 3
            interactive: false
            leading: Component {
                Step {
                    number: 2
                    done: false
                }
            }
            trailing: Component {
                MButton {
                    variant: remembered.googleRegistered ? "filled" : "tonal"
                    text: i18n("Open")
                    onClicked: page.openStore()
                }
            }
        }
    }

    Group {
        title: i18n("Your apps")
        visible: page.ready && !page.busy

        Repeater {
            model: page.userApps

            delegate: ListItem {
                id: row
                required property var modelData
                title: modelData.name
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
        ListItem {
            visible: page.userApps.length === 0
            title: i18n("No apps yet")
            subtitle: page.google ? i18n("Open an APK file, or get apps from Google Play") : i18n("Open an APK file to install an app")
            icon: "kernora-android"
            iconStyle: "plain"
            interactive: false
        }
        ListItem {
            title: i18n("Install an app from an APK file")
            icon: "kernora-apk-install"
            iconStyle: "plain"
            chevron: true
            onClicked: Process.startDetached("kernora-apkinstaller", [])
        }
        ListItem {
            visible: page.google
            title: i18n("Google Play")
            subtitle: i18n("Find and install apps")
            icon: "kernora-google-play"
            iconStyle: "plain"
            chevron: true
            onClicked: page.openStore()
        }
    }

    component Step: Rectangle {
        id: step
        property int number
        property bool done
        implicitWidth: 32
        implicitHeight: 32
        radius: 16
        color: done ? M3.primary : M3.secondaryContainer
        MText {
            anchors.centerIn: parent
            visible: !step.done
            role: "labelLarge"
            text: step.number
            color: M3.secondaryContainerContent
        }
        MIcon {
            anchors.centerIn: parent
            visible: step.done
            size: 20
            source: "checkmark"
            color: M3.primaryContent
        }
    }

    Group {
        visible: page.ready && !page.busy

        ListItem {
            title: i18n("Open apps faster")
            subtitle: i18n("Keeps Android apps ready from the moment you sign in. Uses about 1 GB of memory.")
            icon: "kernora-speed"
            iconStyle: "plain"
            checkable: true
            checked: page.faster
            onToggled: on => {
                page.faster = on;
                Process.run("systemctl", ["--user", on ? "enable" : "disable", "kernora-android.service"], () => page.refresh());
            }
        }
        ListItem {
            title: i18n("Storage")
            subtitle: i18n("Android apps and their data")
            value: page.size(Number(page.info.size || 0))
            icon: "drive-harddisk"
            iconStyle: "plain"
            interactive: false
        }
        ListItem {
            title: i18n("Report a problem")
            subtitle: page.reporting ? i18n("Collecting what Android apps have logged…")
                                     : i18n("Saves Android's logs in a file you can send to Kernora's developers")
            icon: "preferences-desktop-feedback"
            iconStyle: "plain"
            enabled: !page.reporting
            onClicked: page.saveReport()
        }
        ListItem {
            title: i18n("Remove Android apps")
            subtitle: i18n("Deletes every Android app and its data")
            icon: "edit-delete"
            iconStyle: "plain"
            destructive: true
            onClicked: removeDialog.open()
        }
    }

    Dialog {
        id: removeDialog
        title: i18n("Remove Android apps?")
        text: i18n("Every Android app and all of its data are deleted from this computer. You can set them up again later.")
        acceptText: i18n("Remove")
        destructive: true
        onAccepted: page.request("remove")
    }
}
