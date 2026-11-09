/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Dialogs as Dialogs
import org.kernora.m3
import org.kernora.ui
import org.kernora.system

Window {
    id: app

    readonly property int margin: 40
    readonly property string tool: "/usr/libexec/kernora-android"
    readonly property int androidSdk: 33

    property string file: ""
    property var apk: ({})
    property var android: ({})
    property bool androidLoaded: false
    property string phase: "idle"
    property bool leaving: false

    readonly property string label: (apk.label || "").length > 0 ? apk.label : (apk.package || "")
    readonly property bool readable: file.length > 0 && (apk.error || "") === "" && (apk.package || "").length > 0
    readonly property bool androidReady: android.ready === "yes" && android.installed === "yes"
    readonly property bool tooNew: readable && apk.minSdk > androidSdk
    readonly property bool update: readable && Android.hasApp(apk.package)
    readonly property bool runs: apk.compatible || android.arm !== "unsupported"
    readonly property bool armPending: readable && !apk.compatible && androidReady && android.arm === "no"
    readonly property bool needsWayland: android.display === "x11"
    readonly property bool canInstall: readable && runs && !armPending && !tooNew && !needsWayland && androidReady
    readonly property bool working: phase === "starting" || phase === "installing"
    readonly property bool blocked: readable && phase === "idle" && (!runs || armPending || tooNew || needsWayland)
    readonly property bool needsSetup: readable && phase === "idle" && !blocked && androidLoaded && !androidReady

    flags: Qt.Dialog | Qt.FramelessWindowHint
    color: "transparent"
    width: 380 + margin * 2
    height: card.implicitHeight + margin * 2
    visible: true
    title: app.label.length > 0 ? app.label : i18n("Android App Installer")

    function size(bytes: real): string {
        return bytes >= 1048576 ? i18n("%1 MB", (bytes / 1048576).toLocaleString(Qt.locale(), "f", 1))
                                : i18n("%1 KB", Math.max(1, Math.round(bytes / 1024)));
    }

    function open(url: string): void {
        app.file = url;
        app.phase = "idle";
        app.apk = url.length > 0 ? Android.inspect(url) : {};
    }

    function handleArguments(args: var): void {
        for (const argument of args || []) {
            const url = String(argument);
            if (url.startsWith("file:")) {
                open(url);
                return;
            }
        }
    }

    function refreshAndroid(): void {
        Process.run(app.tool, ["status"], (code, output) => {
            const values = {};
            for (const line of output.split("\n")) {
                const at = line.indexOf("=");
                if (at > 0) {
                    values[line.slice(0, at)] = line.slice(at + 1);
                }
            }
            app.android = values;
            app.androidLoaded = true;
        });
    }

    function install(): void {
        app.phase = Android.running ? "installing" : "starting";
        if (!Android.running) {
            Android.start(ok => {
                if (!ok) {
                    app.phase = "failed";
                    return;
                }
                app.phase = "installing";
                app.installNow();
            });
            return;
        }
        installNow();
    }

    function installNow(): void {
        Android.install(app.file, app.apk.package, ok => {
            app.phase = ok ? "installed" : "failed";
        });
    }

    function leave(): void {
        if (leaving) {
            return;
        }
        leaving = true;
        exit.start();
    }

    Component.onCompleted: {
        refreshAndroid();
        handleArguments(startArguments);
    }

    Timer {
        interval: 3000
        repeat: true
        running: app.readable && (!app.androidReady || app.armPending) && app.active
        onTriggered: app.refreshAndroid()
    }

    Shortcut {
        sequence: "Escape"
        enabled: !app.working
        onActivated: app.leave()
    }

    readonly property string step: {
        if (file.length === 0) {
            return i18n("Install an app");
        }
        if (!readable) {
            return i18n("Can't open this file");
        }
        switch (phase) {
        case "starting":
        case "installing":
            return update ? i18n("Updating…") : i18n("Installing…");
        case "installed":
            return update ? i18n("App updated") : i18n("App installed");
        case "failed":
            return i18n("App not installed");
        }
        if (armPending && phase === "idle") {
            return i18n("Almost ready");
        }
        if (blocked || (androidLoaded && android.live === "yes")) {
            return i18n("Can't install this app");
        }
        if (needsSetup) {
            return i18n("Set up Android apps first");
        }
        return update ? i18n("Update this app?") : i18n("Install this app?");
    }

    readonly property string message: {
        if (file.length === 0) {
            return i18n("Choose an APK file.");
        }
        if (!readable) {
            return apk.error === "unreadable" ? i18n("It may be damaged or not fully downloaded.")
                                              : i18n("Only APK files can be installed.");
        }
        if (phase === "failed") {
            return i18n("Something went wrong. Try again.");
        }
        if (phase !== "idle") {
            return "";
        }
        if (!runs) {
            return i18n("It only runs on phones with ARM processors.");
        }
        if (armPending) {
            return i18n("Android apps are still getting ready for apps made for phones. Try again in a few minutes.");
        }
        if (tooNew) {
            return i18n("It's made for newer phones and doesn't run here yet.");
        }
        if (needsWayland) {
            return i18n("Android apps only run in a Wayland session. You can switch to it in Settings.");
        }
        if (androidLoaded && android.live === "yes") {
            return i18n("Android apps work once Kernora is installed on this computer.");
        }
        if (needsSetup) {
            return i18n("Turn them on in Settings, then open this file again.");
        }
        return "";
    }

    MultiEffect {
        source: card
        anchors.fill: card
        shadowEnabled: true
        shadowColor: "#000000"
        shadowOpacity: 0.4
        shadowBlur: 1.0
        shadowVerticalOffset: 8
        blurMax: 48
        opacity: card.opacity
        scale: card.scale
    }

    Rectangle {
        id: card
        x: app.margin
        y: app.margin
        width: app.width - app.margin * 2
        implicitHeight: content.implicitHeight + 48
        height: implicitHeight
        radius: M3.classic ? M3.cornerDialog : 28
        color: M3.surfaceContainerHigh
        opacity: 0
        scale: 0.92

        MSpring {
            dampingRatio: M3.springExpressiveDefaultDamping
            response: M3.springExpressiveDefaultResponse
            onValueChanged: {
                card.opacity = Math.min(1, value);
                card.scale = 0.92 + 0.08 * value;
            }
            Component.onCompleted: animateTo(1)
        }

        ParallelAnimation {
            id: exit
            NumberAnimation { target: card; property: "opacity"; to: 0; duration: M3.durationShort4; easing.type: Easing.InCubic }
            NumberAnimation { target: card; property: "scale"; to: 0.94; duration: M3.durationShort4; easing.type: Easing.InCubic }
            onFinished: Qt.quit()
        }

        DragHandler {
            target: null
            onActiveChanged: {
                if (active) {
                    app.startSystemMove();
                }
            }
        }

        ColumnLayout {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 24
            spacing: 0

            MText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                role: "titleMedium"
                color: M3.surfaceVariantContent
                text: app.step
                wrapMode: Text.Wrap
            }

            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 24
                implicitWidth: 72
                implicitHeight: 72

                Rectangle {
                    anchors.fill: parent
                    visible: appIcon.status !== Image.Ready
                    radius: width / 2
                    color: app.readable ? M3.primaryContainer : M3.surfaceContainerHighest
                    MIcon {
                        anchors.centerIn: parent
                        size: 36
                        source: "kernora-apk-install"
                        color: app.readable ? M3.primaryContainerContent : M3.surfaceVariantContent
                    }
                }
                Image {
                    id: appIcon
                    anchors.fill: parent
                    source: app.readable ? (app.apk.icon || "") : ""
                    sourceSize: Qt.size(192, 192)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                }
            }

            MText {
                Layout.fillWidth: true
                Layout.topMargin: 16
                visible: app.readable
                horizontalAlignment: Text.AlignHCenter
                role: "headlineSmall"
                text: app.label
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            MText {
                Layout.fillWidth: true
                Layout.topMargin: 4
                visible: app.readable
                horizontalAlignment: Text.AlignHCenter
                role: "bodyMedium"
                color: M3.surfaceVariantContent
                text: (app.apk.versionName || "").length > 0
                      ? i18n("Version %1 · %2", app.apk.versionName, app.size(app.apk.size))
                      : app.size(app.apk.size)
                elide: Text.ElideRight
            }

            MText {
                Layout.fillWidth: true
                Layout.topMargin: 16
                visible: text.length > 0
                horizontalAlignment: Text.AlignHCenter
                role: "bodyMedium"
                color: M3.surfaceContent
                text: app.message
                wrapMode: Text.Wrap
            }

            LinearProgress {
                Layout.fillWidth: true
                Layout.topMargin: 24
                visible: app.working
                indeterminate: true
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 24
                spacing: 8

                Item {
                    Layout.fillWidth: true
                }
                MButton {
                    visible: !app.working && app.phase !== "installed"
                    variant: "tonal"
                    text: i18n("Cancel")
                    onClicked: app.leave()
                }
                MButton {
                    visible: app.phase === "installed"
                    variant: "tonal"
                    text: i18n("Done")
                    onClicked: app.leave()
                }
                MButton {
                    visible: app.file.length === 0 || !app.readable
                    text: i18n("Choose file")
                    onClicked: fileDialog.open()
                }
                MButton {
                    visible: (app.needsSetup && app.android.live !== "yes") || (app.blocked && app.needsWayland)
                    text: i18n("Open Settings")
                    onClicked: {
                        Process.startDetached("kernora-settings", ["android"]);
                        app.leave();
                    }
                }
                MButton {
                    visible: app.canInstall && !app.working && app.phase !== "installed"
                    text: app.phase === "failed" ? i18n("Try again") : (app.update ? i18n("Update") : i18n("Install"))
                    onClicked: app.install()
                }
                MButton {
                    visible: app.phase === "installed"
                    text: i18n("Open")
                    onClicked: {
                        Android.launch(app.apk.package);
                        app.leave();
                    }
                }
            }
        }
    }

    DropArea {
        anchors.fill: parent
        enabled: !app.working
        onDropped: drop => {
            const url = drop.urls.map(u => String(u)).find(u => u.startsWith("file:"));
            if (url) {
                app.open(url);
            }
        }
    }

    Dialogs.FileDialog {
        id: fileDialog
        title: i18n("Choose an Android app")
        nameFilters: [i18n("Android apps (*.apk)")]
        currentFolder: Files.standardFolder("downloads")
        onAccepted: app.open(String(selectedFile))
    }
}
