/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Dialogs as Dialogs
import org.kernora.m3
import org.kernora.ui
import org.kernora.system

AppWindow {
    id: app

    width: 440
    height: 520
    minimumWidth: 400
    minimumHeight: 480
    visible: true
    title: app.label.length > 0 ? app.label : i18n("Android App Installer")

    readonly property string tool: "/usr/libexec/kernora-android"
    readonly property int androidRelease: 13
    readonly property int androidSdk: 33

    property string file: ""
    property var apk: ({})
    property var android: ({})
    property bool androidLoaded: false
    property string phase: "idle"

    readonly property string label: (apk.label || "").length > 0 ? apk.label : (apk.package || "")
    readonly property bool readable: file.length > 0 && (apk.error || "") === "" && (apk.package || "").length > 0
    readonly property bool androidReady: android.ready === "yes" && android.installed === "yes"
    readonly property bool tooNew: readable && apk.minSdk > androidSdk
    readonly property bool update: readable && Android.hasApp(apk.package)
    readonly property bool canInstall: readable && apk.compatible && !tooNew && androidReady

    function releaseFor(sdk: int): string {
        const releases = { 34: "14", 35: "15", 36: "16", 37: "17" };
        return releases[sdk] || String(sdk - 20);
    }

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

    Component.onCompleted: {
        refreshAndroid();
        handleArguments(startArguments);
    }

    Timer {
        interval: 3000
        repeat: true
        running: app.readable && !app.androidReady && app.active
        onTriggered: app.refreshAndroid()
    }

    readonly property string headline: {
        if (file.length === 0) {
            return i18n("Install an Android app");
        }
        if (!readable) {
            return i18n("This file isn't an Android app");
        }
        return app.label;
    }

    readonly property string message: {
        if (file.length === 0) {
            return i18n("Choose an APK file to install it on this computer.");
        }
        if (!readable) {
            return apk.error === "unreadable" ? i18n("Kernora can't open this file. It may be damaged or not fully downloaded.")
                                              : i18n("Kernora can install apps from APK files. App bundles in other formats aren't supported yet.");
        }
        switch (phase) {
        case "starting":
            return i18n("Starting Android…");
        case "installing":
            return update ? i18n("Updating…") : i18n("Installing…");
        case "installed":
            return update ? i18n("The app is updated.") : i18n("The app is installed. You can find it with your other apps.");
        case "failed":
            return i18n("The app couldn't be installed. It may not work with this version of Android.");
        }
        if (!apk.compatible) {
            return i18n("This app is made only for phones with ARM processors, so it doesn't run on this computer.");
        }
        if (tooNew) {
            return i18n("This app needs Android %1 or newer. Kernora runs Android %2.", releaseFor(apk.minSdk), androidRelease);
        }
        if (androidLoaded && android.live === "yes") {
            return i18n("Android apps work after Kernora is installed on this computer.");
        }
        if (androidLoaded && !androidReady) {
            return i18n("Android apps are off. Turn them on in Settings, then install this app.");
        }
        return update ? i18n("Do you want to update this app?") : i18n("Do you want to install this app?");
    }

    readonly property bool problem: (file.length > 0 && !readable) || phase === "failed"
                                    || (readable && phase === "idle" && (!apk.compatible || tooNew))

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 0

        Item {
            Layout.fillHeight: true
        }

        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 112
            implicitHeight: 112

            MShape {
                anchors.fill: parent
                visible: appIcon.status !== Image.Ready
                shape: M3.classic ? "circle" : "cookie9"
                color: app.problem ? M3.errorContainer : M3.primaryContainer
            }
            MIcon {
                anchors.centerIn: parent
                visible: appIcon.status !== Image.Ready
                size: 52
                source: app.problem ? "dialog-error" : "kernora-apk-install"
                color: app.problem ? M3.errorContainerContent : M3.primaryContainerContent
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
            Layout.topMargin: 20
            horizontalAlignment: Text.AlignHCenter
            role: "headlineSmall"
            text: app.headline
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        MText {
            Layout.fillWidth: true
            Layout.topMargin: 6
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
            Layout.topMargin: 2
            visible: app.readable
            horizontalAlignment: Text.AlignHCenter
            role: "bodySmall"
            color: M3.surfaceVariantContent
            text: app.apk.package || ""
            elide: Text.ElideMiddle
        }

        MText {
            Layout.fillWidth: true
            Layout.topMargin: 24
            horizontalAlignment: Text.AlignHCenter
            role: "bodyLarge"
            color: app.problem ? M3.error : M3.surfaceContent
            text: app.message
            wrapMode: Text.Wrap
        }

        LinearProgress {
            Layout.fillWidth: true
            Layout.topMargin: 20
            Layout.leftMargin: 32
            Layout.rightMargin: 32
            visible: app.phase === "starting" || app.phase === "installing"
            indeterminate: true
        }

        Item {
            Layout.fillHeight: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Item {
                Layout.fillWidth: true
            }
            QQC2.Button {
                visible: app.phase !== "installed"
                enabled: app.phase !== "starting" && app.phase !== "installing"
                flat: true
                text: i18n("Cancel")
                onClicked: Qt.quit()
            }
            QQC2.Button {
                visible: app.file.length === 0 || !app.readable
                highlighted: true
                text: i18n("Choose a file")
                icon.name: "document-open"
                onClicked: fileDialog.open()
            }
            QQC2.Button {
                visible: app.readable && app.androidLoaded && !app.androidReady && app.android.live !== "yes"
                         && app.apk.compatible && !app.tooNew
                highlighted: true
                text: i18n("Turn on Android")
                icon.name: "kernora-android"
                onClicked: Process.startDetached("kernora-settings", ["android"])
            }
            QQC2.Button {
                visible: app.canInstall && app.phase !== "installed"
                enabled: app.phase === "idle" || app.phase === "failed"
                highlighted: true
                text: app.phase === "failed" ? i18n("Try again") : (app.update ? i18n("Update") : i18n("Install"))
                icon.name: "download"
                onClicked: app.install()
            }
            QQC2.Button {
                visible: app.phase === "installed"
                flat: true
                text: i18n("Done")
                onClicked: Qt.quit()
            }
            QQC2.Button {
                visible: app.phase === "installed"
                highlighted: true
                text: i18n("Open")
                icon.name: "media-playback-start"
                onClicked: {
                    Android.launch(app.apk.package);
                    Qt.quit();
                }
            }
        }
    }

    DropArea {
        anchors.fill: parent
        enabled: app.phase !== "starting" && app.phase !== "installing"
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
