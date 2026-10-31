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
    readonly property string store: "com.android.vending"
    property var info: ({})
    property bool loaded: false
    property string choice: "vanilla"
    property bool actionFailed: false
    property real requestedAt: 0
    property string androidId: ""
    property bool faster: false

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
    readonly property var userApps: Android.apps.filter(app => app.package !== page.store)

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
            case "downloading":
                if (remaining >= 60) {
                    return i18np("About %1 minute left. You can keep using the computer.",
                                 "About %1 minutes left. You can keep using the computer.", Math.ceil(remaining / 60));
                }
                if (remaining >= 0) {
                    return i18n("Less than a minute left. You can keep using the computer.");
                }
                return i18n("This takes a few minutes. You can keep using the computer.");
            default:
                return i18n("This takes a few minutes. You can keep using the computer.");
            }
        }
        if (failed) {
            return status === "offline" ? i18n("Everything apps need is downloaded from the internet. Connect to a network and try again.")
                                        : i18n("Check the internet connection and that there is enough free space, then try again.");
        }
        return "";
    }

    component Choice: Item {
        id: card

        property string value
        property string icon
        property string title
        property string text
        property string amount
        readonly property bool selected: page.choice === value

        implicitHeight: body.implicitHeight + 40
        activeFocusOnTab: true
        Accessible.role: Accessible.RadioButton
        Accessible.name: title
        Accessible.checked: selected
        Keys.onSpacePressed: page.choice = value
        Keys.onReturnPressed: page.choice = value

        MMorph {
            id: selectMorph
            active: card.selected
            dampingRatio: M3.springExpressiveDefaultDamping
            response: M3.springExpressiveDefaultResponse
        }

        Rectangle {
            id: surface
            anchors.fill: parent
            radius: M3.classic ? M3.cornerCard : 20 + 12 * selectMorph.value
            color: card.selected ? M3.secondaryContainer : M3.surfaceContainerHigh
            Behavior on color { ColorAnimation { duration: M3.durationShort4 } }

            MStateLayer {
                radius: surface.radius
                color: M3.surfaceContent
                hovered: mouse.containsMouse
                pressed: mouse.pressed
                focused: card.activeFocus
                pressPoint: Qt.point(mouse.mouseX, mouse.mouseY)
            }
        }

        ColumnLayout {
            id: body
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 20
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Item {
                    implicitWidth: 48
                    implicitHeight: 48
                    MShape {
                        anchors.fill: parent
                        shape: M3.classic ? "circle" : (card.selected ? "cookie9" : "circle")
                        color: card.selected ? M3.primary : M3.secondaryContainer
                        rotation: 45 * selectMorph.value
                    }
                    MIcon {
                        anchors.centerIn: parent
                        size: 24
                        source: card.icon
                        color: card.selected ? M3.primaryContent : M3.secondaryContainerContent
                    }
                }
                Item {
                    Layout.fillWidth: true
                }
                Rectangle {
                    implicitWidth: 28
                    implicitHeight: 28
                    radius: 14
                    color: M3.primary
                    scale: selectMorph.value
                    opacity: selectMorph.value
                    MIcon {
                        anchors.centerIn: parent
                        size: 20
                        source: "checkmark"
                        color: M3.primaryContent
                    }
                }
            }
            MText {
                Layout.fillWidth: true
                role: "titleMedium"
                text: card.title
                color: card.selected ? M3.secondaryContainerContent : M3.surfaceContent
                wrapMode: Text.Wrap
            }
            MText {
                Layout.fillWidth: true
                role: "bodyMedium"
                text: card.text
                color: card.selected ? M3.secondaryContainerContent : M3.surfaceVariantContent
                wrapMode: Text.Wrap
            }
            MText {
                Layout.fillWidth: true
                role: "labelLarge"
                text: card.amount
                color: card.selected ? M3.secondaryContainerContent : M3.primary
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: page.choice = card.value
        }
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
            RotationAnimator on rotation {
                from: 0
                to: 360
                duration: 24000
                loops: Animation.Infinite
                running: page.busy && art.visible && M3.motionScale > 0 && !M3.classic
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
                            : i18n("Apps made for Android phones and tablets, in their own windows, right next to your other apps.")
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
                    visible: page.busy && page.status === "downloading"
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
                indeterminate: page.status !== "downloading"
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
        title: i18n("Where your apps come from")
        note: i18n("Android apps take about 3 GB of disk space. Banking apps and games with anti-cheat only run on phones.")
        visible: page.loaded && !page.live && !page.ready && !page.busy

        GridLayout {
            width: parent.width
            columns: width > 520 ? 2 : 1
            columnSpacing: 12
            rowSpacing: 12

            Choice {
                Layout.fillWidth: true
                Layout.fillHeight: true
                value: "vanilla"
                icon: "kernora-apk-install"
                title: i18n("APK files")
                text: i18n("Install apps from APK files and from open app stores like F-Droid.")
                amount: i18n("About 1 GB to download")
            }
            Choice {
                Layout.fillWidth: true
                Layout.fillHeight: true
                value: "gapps"
                icon: "kernora-google-play"
                title: i18n("Google Play")
                text: i18n("APK files plus the Play Store and Google services. Google asks you to register this computer once.")
                amount: i18n("About 1.4 GB to download")
            }
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
            onClicked: Android.launch(page.store)
        }
    }

    Group {
        title: i18n("Google Play")
        note: i18n("Before you sign in to the Play Store, register this computer with Google: copy the device ID and paste it on Google's page.")
        visible: page.ready && !page.busy && page.google

        ListItem {
            title: i18n("Register with Google")
            subtitle: page.androidId.length > 0 ? i18n("Device ID: %1", page.androidId) : i18n("Shows the device ID and opens Google's page")
            icon: "kernora-google-play"
            iconStyle: "plain"
            chevron: true
            onClicked: Process.run("pkexec", [page.tool, "android-id"], (code, output) => {
                page.androidId = output.trim();
                if (page.androidId.length > 0) {
                    Android.copyText(page.androidId);
                    page.notify(i18n("Device ID copied"));
                    Process.openUrl("https://www.google.com/android/uncertified");
                } else {
                    page.notify(i18n("Open Google Play once, then try again"));
                }
            })
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
