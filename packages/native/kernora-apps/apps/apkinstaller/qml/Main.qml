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
    readonly property bool canInstall: readable && apk.compatible && !tooNew && androidReady
    readonly property bool working: phase === "starting" || phase === "installing"
    readonly property bool problem: (file.length > 0 && !readable) || phase === "failed"
                                    || (readable && phase === "idle" && (!apk.compatible || tooNew))

    flags: Qt.Dialog | Qt.FramelessWindowHint
    color: "transparent"
    width: 400 + margin * 2
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
        running: app.readable && !app.androidReady && app.active
        onTriggered: app.refreshAndroid()
    }

    Shortcut {
        sequence: "Escape"
        enabled: !app.working
        onActivated: app.leave()
    }

    readonly property string headline: {
        if (file.length === 0) {
            return i18n("Install an Android app");
        }
        if (!readable) {
            return i18n("This file isn't an app");
        }
        return app.label;
    }

    readonly property string message: {
        if (file.length === 0) {
            return i18n("Choose an APK file to install the app on this computer.");
        }
        if (!readable) {
            return apk.error === "unreadable" ? i18n("This file can't be opened. It may be damaged or not fully downloaded.")
                                              : i18n("Apps install from APK files. App bundles in other formats aren't supported yet.");
        }
        switch (phase) {
        case "starting":
            return i18n("Getting ready…");
        case "installing":
            return update ? i18n("Updating…") : i18n("Installing…");
        case "installed":
            return update ? i18n("App updated") : i18n("App installed");
        case "failed":
            return i18n("The app couldn't be installed.");
        }
        if (!apk.compatible) {
            return i18n("This app is made only for phones with ARM processors, so it doesn't run on this computer.");
        }
        if (tooNew) {
            return i18n("This app is made for newer phones and doesn't run here yet.");
        }
        if (androidLoaded && android.live === "yes") {
            return i18n("Android apps work after Kernora is installed on this computer.");
        }
        if (androidLoaded && !androidReady) {
            return i18n("Set up Android apps in Settings, then install this app.");
        }
        return update ? i18n("Do you want to update this app?") : i18n("Do you want to install this app?");
    }

    MultiEffect {
        source: card
        anchors.fill: card
        shadowEnabled: true
        shadowColor: "#000000"
        shadowOpacity: 0.45
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
        implicitHeight: content.implicitHeight + 56
        height: implicitHeight
        radius: M3.classic ? M3.cornerCard : 28
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

        MMorph {
            id: doneMorph
            active: app.phase === "installed"
            dampingRatio: M3.springExpressiveDefaultDamping
            response: M3.springExpressiveDefaultResponse
        }

        ColumnLayout {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 28
            spacing: 0

            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 128
                implicitHeight: 128

                MShape {
                    id: halo
                    anchors.fill: parent
                    shape: M3.classic ? "circle" : (app.phase === "installed" ? "sunny" : (app.working ? "cookie12" : "cookie9"))
                    color: app.problem ? M3.errorContainer : (app.phase === "installed" ? M3.tertiaryContainer : M3.primaryContainer)
                    scale: 0.94 + 0.06 * doneMorph.value
                    Behavior on color { ColorAnimation { duration: M3.durationMedium2 } }
                    RotationAnimator on rotation {
                        from: 0
                        to: 360
                        duration: 6000
                        loops: Animation.Infinite
                        running: app.working && halo.visible && M3.motionScale > 0 && !M3.classic
                    }
                }
                MIcon {
                    anchors.centerIn: parent
                    visible: appIcon.status !== Image.Ready
                    size: 48
                    source: app.problem ? "dialog-error" : "kernora-apk-install"
                    color: app.problem ? M3.errorContainerContent : M3.primaryContainerContent
                }
                Image {
                    id: appIcon
                    anchors.centerIn: parent
                    width: 80
                    height: 80
                    source: app.readable ? (app.apk.icon || "") : ""
                    sourceSize: Qt.size(192, 192)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                }
                Rectangle {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 10
                    width: 32
                    height: 32
                    radius: 16
                    color: M3.primary
                    border.width: 3
                    border.color: card.color
                    scale: doneMorph.value
                    visible: scale > 0.01
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
                Layout.topMargin: 20
                horizontalAlignment: Text.AlignHCenter
                role: app.phase === "installed" ? "titleMedium" : "bodyLarge"
                color: app.problem ? M3.error : M3.surfaceContent
                text: app.message
                wrapMode: Text.Wrap
            }

            LinearProgress {
                Layout.fillWidth: true
                Layout.topMargin: 16
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                visible: app.working
                indeterminate: true
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 28
                spacing: 8

                MButton {
                    Layout.fillWidth: true
                    visible: app.phase !== "installed"
                    enabled: !app.working
                    variant: "tonal"
                    text: i18n("Cancel")
                    onClicked: app.leave()
                }
                MButton {
                    Layout.fillWidth: true
                    visible: app.file.length === 0 || !app.readable
                    text: i18n("Choose a file")
                    icon: "document-open"
                    onClicked: fileDialog.open()
                }
                MButton {
                    Layout.fillWidth: true
                    visible: app.readable && app.androidLoaded && !app.androidReady && app.android.live !== "yes"
                             && app.apk.compatible && !app.tooNew
                    text: i18n("Set up")
                    icon: "kernora-android"
                    onClicked: Process.startDetached("kernora-settings", ["android"])
                }
                MButton {
                    Layout.fillWidth: true
                    visible: app.canInstall && app.phase !== "installed"
                    enabled: app.phase === "idle" || app.phase === "failed"
                    text: app.phase === "failed" ? i18n("Try again") : (app.update ? i18n("Update") : i18n("Install"))
                    onClicked: app.install()
                }
                MButton {
                    Layout.fillWidth: true
                    visible: app.phase === "installed"
                    variant: "tonal"
                    text: i18n("Done")
                    onClicked: app.leave()
                }
                MButton {
                    Layout.fillWidth: true
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
