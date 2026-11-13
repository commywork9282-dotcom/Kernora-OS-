/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Shapes
import org.kde.kirigami as Kirigami
import org.kde.layershell as LayerShell
import org.kernora.m3
import org.kernora.ui
import org.kernora.system

AppWindow {
    id: app

    width: kernelPanic ? 760 : 900
    height: whatsNew ? 720 : kernelPanic ? 660 : 640
    minimumWidth: 560
    minimumHeight: 520
    color: M3.surfaceContainer
    visible: !(firstRun && SystemInfo.live) && !(whatsNew && notes.length === 0) && !(kernelPanic && !panic.id) && !heroActive
    title: kernelPanic ? i18n("Kernora restarted") : heroActive ? i18n("Meet KED 2") : whatsNew ? i18n("What's new") : i18n("Welcome")

    property int page: 0
    readonly property int pages: 6

    ConfigEntry {
        id: showOnLogin
        file: "kernora-welcomerc"
        group: "General"
        key: "ShowOnLogin"
        defaultValue: true
    }

    ConfigEntry {
        id: seenNotes
        file: "kernora-welcomerc"
        group: "WhatsNew"
        key: "Seen"
        defaultValue: ""
    }

    function retire(): void {
        if (special || SystemInfo.live) {
            return;
        }
        showOnLogin.value = false;
        const folder = String(StandardPaths.writableLocation(StandardPaths.ApplicationsLocation)).replace(/^file:\/\//, "");
        const entry = folder + "/org.kernora.welcome.desktop";
        Config.write(entry, "Desktop Entry", "Type", "Application", false);
        Config.write(entry, "Desktop Entry", "Name", "Welcome", false);
        Config.write(entry, "Desktop Entry", "Icon", "org.kernora.welcome", false);
        Config.write(entry, "Desktop Entry", "Exec", "kernora-welcome", false);
        Config.write(entry, "Desktop Entry", "NoDisplay", true);
    }

    function finish(): void {
        retire();
        Qt.quit();
    }

    onClosing: retire()
    function handleArguments(args: var): void {
        if (tourWaiting) {
            showBubble(tourStep + 1);
        }
    }

    readonly property bool firstRun: (startArguments || []).indexOf("--first-run") >= 0
    readonly property bool whatsNew: (startArguments || []).indexOf("--whats-new") >= 0
    readonly property bool kernelPanic: (startArguments || []).indexOf("--kernel-panic") >= 0
    readonly property bool special: whatsNew || kernelPanic
    readonly property var panic: kernelPanic ? SystemInfo.kernelPanic() : ({})
    property var notes: []
    readonly property bool heroActive: whatsNew && notes.length > 0 && notes[0].hero === "ked2"

    function cookie(centre: real, radius: real, depth: real, lobes: int): var {
        const points = [];
        for (let step = 0; step <= 360; ++step) {
            const angle = step * Math.PI / 180;
            const r = radius * (1 - depth + depth * Math.cos(lobes * angle));
            points.push(Qt.point(centre + r * Math.cos(angle), centre + r * Math.sin(angle)));
        }
        return points;
    }

    Component.onCompleted: {
        if (firstRun && SystemInfo.live) {
            Qt.quit();
        }
        if (kernelPanic && !panic.id) {
            Qt.quit();
        }
        if (whatsNew) {
            const releases = SystemInfo.releaseNotes();
            const seen = releases.findIndex(r => r.id === String(seenNotes.value));
            const picked = seen > 0 ? releases.slice(0, seen) : releases.slice(0, seen === 0 ? 1 : 3);
            const merged = [];
            for (const release of picked) {
                const last = merged[merged.length - 1];
                if (last && last.date === release.date) {
                    last.items = last.items.concat(release.items);
                } else {
                    merged.push({ id: release.id, date: release.date, items: Array.from(release.items), hero: release.hero });
                }
            }
            notes = merged;
            if (releases.length > 0) {
                seenNotes.value = releases[0].id;
            } else {
                Qt.quit();
            }
            if (heroActive) {
                greeting = greetingComponent.createObject(null);
            }
        }
    }

    Shortcut { enabled: !app.special; sequences: ["Right", "PgDown"]; onActivated: app.page = Math.min(app.pages - 1, app.page + 1) }
    Shortcut { enabled: !app.special; sequences: ["Left", "PgUp"]; onActivated: app.page = Math.max(0, app.page - 1) }
    Shortcut { sequence: "Escape"; onActivated: app.finish() }

    RoundedClip {
        anchors.fill: parent
        anchors.margins: 12
        radius: M3.classic ? M3.cornerCard : 28

        Rectangle {
            anchors.fill: parent
            color: M3.surface
        }

        Loader {
            anchors.fill: parent
            active: app.whatsNew && !app.heroActive
            sourceComponent: whatsNewView
        }


        Loader {
            anchors.fill: parent
            active: app.kernelPanic
            sourceComponent: panicView
        }

        Item {
            id: viewport
            anchors.fill: parent
            anchors.bottomMargin: 88
            visible: !app.special

            Repeater {
                model: app.special ? [] : [hello, theme, style, wallpaper, apps, done]
                delegate: Loader {
                    id: pageLoader
                    required property var modelData
                    required property int index
                    width: viewport.width
                    height: viewport.height
                    x: (index - app.page) * viewport.width
                    opacity: index === app.page ? 1 : 0
                    active: Math.abs(index - app.page) <= 1
                    sourceComponent: modelData
                    Behavior on x { NumberAnimation { duration: M3.durationLong2; easing.type: Easing.Bezier; easing.bezierCurve: M3.easingEmphasizedDecelerate } }
                    Behavior on opacity { NumberAnimation { duration: M3.durationMedium2 } }
                }
            }
        }

        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 24
            spacing: 12
            visible: !app.special

            QQC2.Button {
                text: app.page === 0 ? i18n("Skip") : i18n("Back")
                flat: true
                onClicked: app.page === 0 ? app.finish() : app.page -= 1
            }
            Item { Layout.fillWidth: true }
            Row {
                spacing: 8
                Repeater {
                    model: app.pages
                    delegate: Rectangle {
                        required property int index
                        width: index === app.page ? 24 : 8
                        height: 8
                        radius: 4
                        color: index === app.page ? M3.primary : M3.surfaceContainerHighest
                        Behavior on width { NumberAnimation { duration: M3.durationMedium2 } }
                    }
                }
            }
            Item { Layout.fillWidth: true }
            QQC2.Button {
                text: app.page === app.pages - 1 ? i18n("Start using Kernora") : i18n("Next")
                highlighted: true
                onClicked: app.page === app.pages - 1 ? app.finish() : app.page += 1
            }
        }
    }

    component PageColumn: ColumnLayout {
        property string heading
        property string text
        spacing: 12
        MText {
            Layout.fillWidth: true
            Layout.topMargin: 40
            Layout.leftMargin: 48
            Layout.rightMargin: 48
            role: "displaySmall"
            text: parent.heading
            wrapMode: Text.Wrap
        }
        MText {
            Layout.fillWidth: true
            Layout.leftMargin: 48
            Layout.rightMargin: 48
            role: "bodyLarge"
            color: M3.surfaceVariantContent
            text: parent.text
            visible: text.length > 0
            wrapMode: Text.Wrap
        }
    }

    Component {
        id: hello
        Item {
            Loader {
                id: helloScene
                anchors.fill: parent
                source: "file:///usr/share/plasma/wallpapers/org.kernora.shapes/contents/ui/Scene.qml"
                onLoaded: {
                    item.intro = 0;
                    introAnimation.start();
                    item.phase = Qt.binding(() => helloPhase.value % 1);
                }
                NumberAnimation {
                    id: introAnimation
                    target: helloScene.item
                    property: "intro"
                    from: 0
                    to: 1
                    duration: 1600
                }
                QtObject {
                    id: helloPhase
                    property real value: 0.2
                }
                NumberAnimation {
                    target: helloPhase
                    property: "value"
                    running: app.page === 0 && M3.motionScale > 0
                    from: 0.2
                    to: 1.2
                    duration: 300000
                    loops: Animation.Infinite
                }
            }
            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - 96, 520)
                height: helloColumn.implicitHeight + 64
                radius: M3.classic ? M3.cornerDialog : 36
                color: M3.withAlpha(M3.surface, 0.92)

                ColumnLayout {
                    id: helloColumn
                    anchors.centerIn: parent
                    width: parent.width - 64
                    spacing: 12

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 96
                        implicitHeight: 96
                        radius: 48
                        color: M3.primary
                        MIcon {
                            anchors.centerIn: parent
                            size: 60
                            source: "kernora-logo"
                            color: M3.primaryContent
                        }
                    }
                    MText {
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        role: "displaySmall"
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        text: i18n("Welcome to %1", SystemInfo.osName)
                    }
                    MText {
                        Layout.fillWidth: true
                        role: "bodyLarge"
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        color: M3.surfaceVariantContent
                        text: SystemInfo.live
                            ? i18n("You are trying Kernora from the installation medium. Look around, then install it when you are ready.")
                            : i18n("Let's make it yours. It takes a minute.")
                    }
                    QQC2.Button {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 8
                        visible: SystemInfo.live
                        text: i18n("Install Kernora")
                        icon.name: "system-software-install"
                        highlighted: true
                        onClicked: Process.launchApplication("org.kernora.installer.desktop", [])
                    }
                }
            }
        }
    }

    Component {
        id: theme
        PageColumn {
            heading: i18n("Light or dark")
            text: i18n("Choose how Kernora looks. You can change it any time in Settings.")
            Group {
                Layout.preferredWidth: Math.min(520, parent.width - 96)
                Layout.leftMargin: 48
                Layout.topMargin: 24
                enabled: !Appearance.busy
                Repeater {
                    model: [
                        { dark: false, label: i18n("Light") },
                        { dark: true, label: i18n("Dark") }
                    ]
                    delegate: RadioRow {
                        required property var modelData
                        width: parent ? parent.width : implicitWidth
                        title: modelData.label
                        checked: Appearance.dark === modelData.dark
                        onClicked: {
                            if (Appearance.dark !== modelData.dark) {
                                Appearance.setDark(modelData.dark, null);
                            }
                        }
                    }
                }
            }
            Item { Layout.fillHeight: true }
        }
    }

    Component {
        id: style
        PageColumn {
            heading: i18n("Pick a style")
            text: i18n("Three generations of Material, in the Kernora colours. You can change it any time in Settings.")
            Group {
                Layout.preferredWidth: Math.min(520, parent.width - 96)
                Layout.leftMargin: 48
                Layout.topMargin: 24
                enabled: !Appearance.busy
                Repeater {
                    model: [
                        { value: "md3", label: "Material 3", description: i18n("2021 · Material You") },
                        { value: "md2", label: "Material Design 2", description: i18n("2018 · Material Theming") },
                        { value: "md1", label: "Material Design 1", description: i18n("2014 · paper and ink") }
                    ]
                    delegate: RadioRow {
                        required property var modelData
                        width: parent ? parent.width : implicitWidth
                        title: modelData.label
                        subtitle: modelData.description
                        checked: Appearance.generation === modelData.value
                        onClicked: {
                            if (Appearance.generation !== modelData.value && !Appearance.busy) {
                                Appearance.setGeneration(modelData.value, null);
                            }
                        }
                    }
                }
            }
            Item { Layout.fillHeight: true }
        }
    }

    Component {
        id: wallpaper
        PageColumn {
            id: wallpaperPage
            heading: i18n("Pick a wallpaper")
            text: i18n("Kernora's wallpapers are alive: they move slowly and rest behind your windows.")
            property string chosen: "org.kernora.shapes"
            GridLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 48
                Layout.rightMargin: 48
                Layout.topMargin: 16
                columns: Math.max(2, Math.floor(width / 190))
                columnSpacing: 12
                rowSpacing: 12
                Repeater {
                    model: Files.liveWallpapers()
                    delegate: WallpaperChoice {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 100
                        title: modelData.name
                        scene: modelData.scene
                        selected: wallpaperPage.chosen === modelData.id
                        onClicked: {
                            wallpaperPage.chosen = modelData.id;
                            Files.setLiveWallpaper(modelData.id);
                        }
                    }
                }
                Repeater {
                    model: Files.wallpapers().slice(0, 4)
                    delegate: WallpaperChoice {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 100
                        title: modelData.name
                        preview: modelData.preview
                        selected: wallpaperPage.chosen === String(modelData.image)
                        onClicked: {
                            wallpaperPage.chosen = String(modelData.image);
                            Files.setWallpaper(modelData.image);
                        }
                    }
                }
            }
            Item { Layout.fillHeight: true }
        }
    }

    Component {
        id: apps
        PageColumn {
            heading: i18n("Your apps")
            text: i18n("Everything you need is here. Open the launcher with the Meta key to find more.")
            GridLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 40
                Layout.rightMargin: 40
                Layout.topMargin: 16
                columns: Math.max(3, Math.floor(width / 190))
                rowSpacing: 8
                columnSpacing: 8
                Repeater {
                    model: [
                        { id: "librewolf.desktop", name: i18n("Web browser"), icon: "librewolf" },
                        { id: "org.kernora.files.desktop", name: i18n("Files"), icon: "org.kernora.files" },
                        { id: "org.kernora.photos.desktop", name: i18n("Photos"), icon: "org.kernora.photos" },
                        { id: "org.kernora.player.desktop", name: i18n("Media Player"), icon: "org.kernora.player" },
                        { id: "org.kernora.editor.desktop", name: i18n("Text Editor"), icon: "org.kernora.editor" },
                        { id: "org.kernora.calculator.desktop", name: i18n("Calculator"), icon: "org.kernora.calculator" },
                        { id: "org.kernora.screenshot.desktop", name: i18n("Screenshot"), icon: "org.kernora.screenshot" },
                        { id: "org.kernora.terminal.desktop", name: i18n("Terminal"), icon: "org.kernora.terminal" },
                        { id: "org.kernora.settings.desktop", name: i18n("Settings"), icon: "org.kernora.settings" }
                    ]
                    delegate: QQC2.AbstractButton {
                        id: tile
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 100
                        implicitHeight: 64
                        Accessible.name: modelData.name
                        onClicked: Process.launchApplication(modelData.id, [])
                        background: Rectangle {
                            radius: M3.classic ? M3.cornerCard : 20
                            color: M3.surfaceContainer
                            MStateLayer {
                                radius: M3.classic ? M3.cornerCard : 20
                                hovered: tile.hovered
                                pressed: tile.pressed
                            }
                        }
                        contentItem: RowLayout {
                            spacing: 12
                            AppIcon {
                                Layout.leftMargin: 12
                                size: 40
                                name: tile.modelData.icon
                            }
                            MText {
                                Layout.fillWidth: true
                                role: "titleSmall"
                                text: tile.modelData.name
                            }
                        }
                    }
                }
            }
            Item { Layout.fillHeight: true }
        }
    }

    Component {
        id: done
        PageColumn {
            heading: i18n("You're all set")
            text: i18n("A few things worth knowing:")
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 40
                Layout.rightMargin: 40
                Layout.topMargin: 8
                spacing: 2
                ListItem {
                    Layout.fillWidth: true
                    title: i18n("Meta opens the launcher")
                    subtitle: i18n("Start typing to find apps, files and settings")
                    icon: "search"
                    accent: 0
                    interactive: false
                }
                ListItem {
                    Layout.fillWidth: true
                    title: i18n("Network and battery icons open quick settings")
                    subtitle: i18n("Wi-Fi, sound, brightness, Do Not Disturb and more")
                    icon: "preferences-desktop"
                    accent: 1
                    interactive: false
                }
                ListItem {
                    Layout.fillWidth: true
                    title: i18n("Print takes a screenshot")
                    subtitle: i18n("Choose an area, the screen or a window")
                    icon: "kernora-select-region"
                    accent: 4
                    interactive: false
                }
                ListItem {
                    Layout.fillWidth: true
                    title: i18n("Settings has everything else")
                    icon: "applications-system"
                    accent: 3
                    chevron: true
                    onClicked: Process.launchApplication("org.kernora.settings.desktop", [])
                }
            }
            Item { Layout.fillHeight: true }
        }
    }

    property var greeting: null
    property var bubble: null
    property int tourStep: -1
    property bool tourWaiting: false
    readonly property bool stayHidden: greeting !== null || bubble !== null || tourWaiting
    readonly property var tourSteps: [
        { icon: "preferences-desktop", title: i18n("Quick settings"), edge: "topRight", arrow: "up", offset: 28,
          text: i18n("Click the icons on the right: sliders, and tiles for Wi-Fi, Bluetooth and more.") },
        { icon: "notifications", title: i18n("Notifications"), edge: "topRight", arrow: "up", offset: 63,
          text: i18n("The bell opens your notifications. Silent ones have their own section.") },
        { icon: "kernora-logo", title: i18n("Apps menu"), edge: "bottomLeft", arrow: "down", offset: 50,
          text: i18n("All your apps from A to Z, and search for apps, settings, files and the web.") },
        { icon: "view-app-grid", title: i18n("App groups"), edge: "center", arrow: "none", offset: 0,
          text: i18n("Drag one app onto another on the desktop to put them in a group.") },
        { icon: "preferences-desktop-wallpaper", title: i18n("Wallpaper collections"), edge: "bottom", arrow: "none", offset: 0,
          text: i18n("Click here to open Wallpaper & style, with wallpapers sorted into collections.") }
    ]

    function invokeKeys(keys: string): void {
        for (const key of Config.keyList("kglobalshortcutsrc", "plasmashell")) {
            if (String(Config.read("kglobalshortcutsrc", "plasmashell", key, "")).split(",")[0] === keys) {
                DBus.call("session", "org.kde.kglobalaccel", "/component/plasmashell", "org.kde.kglobalaccel.Component",
                          "invokeShortcut", [{ type: "s", value: key }], null);
                return;
            }
        }
    }

    function startTourWatch(): void {
        DBus.call("session", "org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting", "unloadScript",
                  [{ type: "s", value: "kernora-tour-watch" }], () => {
            DBus.call("session", "org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting", "loadScript",
                      [{ type: "s", value: "/usr/share/kernora/welcome/tour-watch.js" }, { type: "s", value: "kernora-tour-watch" }], () => {
                DBus.call("session", "org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting", "start", [], null);
            });
        });
    }

    function stopTourWatch(): void {
        DBus.call("session", "org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting", "unloadScript",
                  [{ type: "s", value: "kernora-tour-watch" }], null);
    }

    function showBubble(step: int): void {
        if (bubble) {
            bubble.destroy();
            bubble = null;
        }
        if (step >= tourSteps.length) {
            finishTour();
            return;
        }
        tourStep = step;
        tourWaiting = step <= 2;
        if (tourWaiting) {
            startTourWatch();
        } else {
            stopTourWatch();
        }
        bubble = bubbleComponent.createObject(null, { step: step });
    }

    function startTour(): void {
        if (greeting) {
            greeting.destroy();
            greeting = null;
        }
        showBubble(0);
    }

    function runBubble(step: int): void {
        if (step === 0) {
            invokeKeys("Meta+Q");
        } else if (step === 1) {
            invokeKeys("Meta+N");
        } else if (step === 2) {
            DBus.call("session", "org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell", "activateLauncherMenu", [], null);
        } else if (step === 3) {
            showBubble(4);
        } else {
            Process.startDetached("kernora-settings", ["appearance"]);
            finishTour();
        }
    }

    function finishTour(): void {
        tourWaiting = false;
        stopTourWatch();
        if (bubble) {
            bubble.destroy();
            bubble = null;
        }
        if (greeting) {
            greeting.destroy();
            greeting = null;
        }
        Qt.quit();
    }

    Component {
        id: greetingComponent
        Window {
            id: hello

            property real shown: M3.motionScale > 0 ? 0 : 1
            NumberAnimation on shown {
                running: M3.motionScale > 0
                to: 1
                duration: 400
                easing.type: Easing.Bezier
                easing.bezierCurve: M3.easingEmphasizedDecelerate
            }

            LayerShell.Window.scope: "kernora-meet-ked2"
            LayerShell.Window.layer: LayerShell.Window.LayerOverlay
            LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
            LayerShell.Window.exclusionZone: -1
            LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityExclusive

            flags: Qt.FramelessWindowHint
            color: "transparent"
            title: i18n("Meet KED 2")
            visible: true

            Shortcut {
                sequence: "Escape"
                onActivated: app.finishTour()
            }
            Shortcut {
                sequences: ["Return", "Enter"]
                onActivated: app.startTour()
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.32 * hello.shown)
            }
            MouseArea {
                anchors.fill: parent
            }

            Kirigami.ShadowedRectangle {
                id: dialog
                anchors.centerIn: parent
                width: 560
                height: actions.y + actions.height + 24
                radius: 28
                color: M3.surfaceContainerHigh
                shadow.size: 28
                shadow.yOffset: 8
                shadow.color: Qt.rgba(0, 0, 0, M3.dark ? 0.5 : 0.22)
                opacity: hello.shown
                scale: 0.94 + 0.06 * hello.shown

                RoundedClip {
                    id: hero
                    x: 16
                    y: 16
                    width: dialog.width - 32
                    height: Math.round(width * 10 / 16)
                    radius: 20
                    Image {
                        anchors.fill: parent
                        source: Qt.resolvedUrl("ked2.jpg")
                        sourceSize.width: 1056
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        mipmap: true
                    }
                }

                Text {
                    id: headline
                    x: 24
                    y: hero.y + hero.height + 24
                    width: dialog.width - 48
                    color: M3.surfaceContent
                    font.family: M3.headlineMedium.family
                    font.pixelSize: M3.headlineMedium.pixelSize
                    font.weight: Font.Normal
                    renderType: Text.QtRendering
                    text: i18n("Meet KED 2")
                }
                MText {
                    id: supporting
                    x: 24
                    y: headline.y + headline.height + 16
                    width: dialog.width - 48
                    role: "bodyMedium"
                    color: M3.surfaceVariantContent
                    wrapMode: Text.Wrap
                    text: i18n("Kernora's new look, inspired by Googlebook. Take a short tour: tips point at what changed, and you can try each thing right away.")
                }
                Row {
                    id: actions
                    anchors.right: parent.right
                    anchors.rightMargin: 24
                    y: supporting.y + supporting.height + 24
                    spacing: 8
                    MButton {
                        variant: "text"
                        text: i18n("Not now")
                        onClicked: app.finishTour()
                    }
                    MButton {
                        text: i18n("Get started")
                        onClicked: app.startTour()
                    }
                }
            }

            Component.onCompleted: requestActivate()
        }
    }

    Component {
        id: bubbleComponent
        Window {
            id: tip

            required property int step
            readonly property var spec: app.tourSteps[step]
            readonly property bool up: spec.arrow === "up"
            readonly property bool down: spec.arrow === "down"
            readonly property real arrowX: spec.edge === "topRight" ? width - spec.offset : spec.edge === "bottomLeft" ? spec.offset : width / 2

            property real shown: M3.motionScale > 0 ? 0 : 1
            NumberAnimation on shown {
                running: M3.motionScale > 0
                to: 1
                duration: 350
                easing.type: Easing.Bezier
                easing.bezierCurve: M3.easingEmphasizedDecelerate
            }

            LayerShell.Window.scope: "kernora-tour"
            LayerShell.Window.layer: LayerShell.Window.LayerTop
            LayerShell.Window.anchors: spec.edge === "topRight" ? (LayerShell.Window.AnchorTop | LayerShell.Window.AnchorRight)
                                     : spec.edge === "bottomLeft" ? (LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft)
                                     : spec.edge === "bottom" ? LayerShell.Window.AnchorBottom
                                     : LayerShell.Window.AnchorNone
            LayerShell.Window.exclusionZone: 0
            LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone

            flags: Qt.FramelessWindowHint
            color: "transparent"
            title: tip.spec.title
            width: 360
            height: card.height + 30
            visible: true

            Item {
                anchors.fill: parent
                opacity: tip.shown
                scale: 0.9 + 0.1 * tip.shown
                transformOrigin: tip.up ? Item.TopRight : tip.down ? Item.BottomLeft : tip.spec.edge === "bottom" ? Item.Bottom : Item.Center

                Kirigami.ShadowedRectangle {
                    id: card
                    x: 6
                    y: tip.up ? 16 : 6
                    width: tip.width - 12
                    height: content.implicitHeight + 32
                    radius: 20
                    corners.topRightRadius: tip.up && tip.spec.edge === "topRight" ? 12 : 20
                    color: M3.tertiary
                    shadow.size: 10
                    shadow.yOffset: 2
                    shadow.color: Qt.rgba(0, 0, 0, M3.dark ? 0.4 : 0.16)

                    Row {
                        id: content
                        x: 16
                        y: 16
                        width: card.width - 32
                        spacing: 14
                        MIcon {
                            size: 24
                            source: tip.spec.icon
                            color: M3.tertiaryContent
                        }
                        Column {
                            width: content.width - 38
                            spacing: 4
                            MText {
                                width: parent.width
                                role: "titleSmall"
                                color: M3.tertiaryContent
                                wrapMode: Text.Wrap
                                text: tip.spec.title
                            }
                            MText {
                                width: parent.width
                                role: "bodyMedium"
                                color: M3.tertiaryContent
                                wrapMode: Text.Wrap
                                maximumLineCount: 4
                                text: tip.spec.text
                            }
                            MText {
                                anchors.right: parent.right
                                role: "labelSmall"
                                color: M3.tertiaryContent
                                opacity: 0.75
                                text: i18n("%1 of %2", tip.step + 1, app.tourSteps.length)
                            }
                        }
                    }

                    MStateLayer {
                        radius: card.radius
                        color: M3.tertiaryContent
                        hovered: tipMouse.containsMouse
                        pressed: tipMouse.pressed
                        pressPoint: Qt.point(tipMouse.mouseX, tipMouse.mouseY)
                    }
                    MouseArea {
                        id: tipMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: app.runBubble(tip.step)
                    }
                }

                Shape {
                    visible: tip.up || tip.down
                    x: tip.arrowX - 9
                    y: tip.up ? 6 : card.y + card.height - 1
                    width: 18
                    height: 11
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        fillColor: M3.tertiary
                        strokeWidth: -1
                        startX: 0
                        startY: tip.up ? 11 : 0
                        PathLine { x: 9; y: tip.up ? 0 : 11 }
                        PathLine { x: 18; y: tip.up ? 11 : 0 }
                        PathLine { x: 0; y: tip.up ? 11 : 0 }
                    }
                }
            }
        }
    }

    Component {
        id: whatsNewView
        Item {
            Flickable {
                id: notesFlick
                anchors.fill: parent
                anchors.bottomMargin: 88
                contentHeight: notesColumn.implicitHeight + 24
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                QQC2.ScrollBar.vertical: QQC2.ScrollBar {}

                ColumnLayout {
                    id: notesColumn
                    width: notesFlick.width
                    spacing: 12

                    RoundedClip {
                        id: banner
                        Layout.fillWidth: true
                        Layout.leftMargin: 24
                        Layout.rightMargin: 24
                        Layout.topMargin: 24
                        Layout.preferredHeight: 200
                        radius: M3.classic ? M3.cornerCard : 28

                        Rectangle {
                            anchors.fill: parent
                            color: M3.darkScheme.surface
                        }
                        Loader {
                            id: bannerScene
                            width: 960
                            height: 600
                            scale: banner.width / 960
                            transformOrigin: Item.TopLeft
                            y: (banner.height - height * scale) / 2
                            source: "file:///usr/share/plasma/wallpapers/org.kernora.shapes/contents/ui/Scene.qml"
                            onLoaded: {
                                item.intro = 1;
                                item.phase = Qt.binding(() => bannerPhase.value % 1);
                            }
                            QtObject {
                                id: bannerPhase
                                property real value: 0.35
                            }
                            NumberAnimation {
                                target: bannerPhase
                                property: "value"
                                running: M3.motionScale > 0
                                from: 0.35
                                to: 1.35
                                duration: 300000
                                loops: Animation.Infinite
                            }
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: 104
                            height: 104
                            radius: 52
                            color: M3.primaryContainer
                            MIcon {
                                anchors.centerIn: parent
                                size: 60
                                source: "kernora-logo"
                                color: M3.primaryContainerContent
                            }
                        }
                    }

                    MText {
                        Layout.fillWidth: true
                        Layout.topMargin: 12
                        Layout.leftMargin: 48
                        Layout.rightMargin: 48
                        role: "displaySmall"
                        wrapMode: Text.Wrap
                        text: i18n("Kernora got even better")
                    }
                    MText {
                        Layout.fillWidth: true
                        Layout.leftMargin: 48
                        Layout.rightMargin: 48
                        role: "bodyLarge"
                        color: M3.surfaceVariantContent
                        wrapMode: Text.Wrap
                        text: app.notes.length === 1 ? i18n("Here is what is new in the update of %1.", app.notes[0].date)
                                                     : i18n("Here is what is new in the latest updates.")
                    }

                    Repeater {
                        model: app.notes
                        delegate: ColumnLayout {
                            id: release
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.leftMargin: 40
                            Layout.rightMargin: 40
                            Layout.topMargin: 8
                            spacing: 2

                            MText {
                                Layout.leftMargin: 8
                                Layout.bottomMargin: 6
                                visible: app.notes.length > 1
                                role: "labelLarge"
                                color: M3.primary
                                text: i18n("Update of %1", release.modelData.date)
                            }
                            Repeater {
                                model: release.modelData.items
                                delegate: ListItem {
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    title: modelData.title
                                    subtitle: modelData.text
                                    icon: modelData.icon
                                    accent: index % 5
                                    maximumSubtitleLines: 4
                                    interactive: false
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 24

                Item { Layout.fillWidth: true }
                QQC2.Button {
                    text: i18n("Great")
                    highlighted: true
                    onClicked: Qt.quit()
                }
            }
        }
    }

    Component {
        id: panicView
        Item {
            id: panicPage
            property bool details: false
            onDetailsChanged: {
                if (details) {
                    reveal.restart();
                }
            }

            Timer {
                id: reveal
                interval: 80
                onTriggered: panicFlick.contentY = Math.max(0, Math.min(panicDetails.y - 24, panicFlick.contentHeight - panicFlick.height))
            }

            Flickable {
                id: panicFlick
                anchors.fill: parent
                anchors.bottomMargin: 88
                contentHeight: panicColumn.implicitHeight + 32
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                QQC2.ScrollBar.vertical: QQC2.ScrollBar {}

                ColumnLayout {
                    id: panicColumn
                    width: panicFlick.width
                    spacing: 16

                    Item {
                        id: face
                        readonly property real side: 176
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 48
                        implicitWidth: side
                        implicitHeight: side

                        Shape {
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer
                            RotationAnimation on rotation {
                                from: 0
                                to: 360
                                duration: 90000
                                loops: Animation.Infinite
                                running: M3.motionScale > 0
                            }
                            ShapePath {
                                strokeWidth: -1
                                strokeColor: "transparent"
                                fillColor: M3.primaryContainer
                                PathPolyline {
                                    path: app.cookie(face.side / 2, face.side / 2, 0.06, 9)
                                }
                            }
                        }
                        Repeater {
                            model: [-1, 1]
                            delegate: Rectangle {
                                required property int modelData
                                width: 16
                                height: 16
                                radius: 8
                                x: face.side / 2 + modelData * 30 - 8
                                y: face.side * 0.38
                                color: M3.primaryContainerContent
                            }
                        }
                        Shape {
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                strokeWidth: 9
                                strokeColor: M3.primaryContainerContent
                                fillColor: "transparent"
                                capStyle: ShapePath.RoundCap
                                startX: face.side / 2 - 34
                                startY: face.side * 0.7
                                PathQuad {
                                    x: face.side / 2 + 34
                                    y: face.side * 0.7
                                    controlX: face.side / 2
                                    controlY: face.side * 0.56
                                }
                            }
                        }
                    }

                    MText {
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        Layout.leftMargin: 56
                        Layout.rightMargin: 56
                        role: "displaySmall"
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        text: i18n("Well, this is awkward.")
                    }
                    MText {
                        Layout.fillWidth: true
                        Layout.leftMargin: 56
                        Layout.rightMargin: 56
                        role: "bodyLarge"
                        color: M3.surfaceVariantContent
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        text: i18n("Kernora encountered a critical kernel error and could no longer continue running. Your computer restarted automatically to recover from this problem.")
                    }
                    MText {
                        Layout.fillWidth: true
                        Layout.leftMargin: 56
                        Layout.rightMargin: 56
                        role: "bodyMedium"
                        color: M3.surfaceVariantContent
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        visible: String(app.panic.when || "").length > 0
                        text: i18n("It happened on %1.", app.panic.when)
                    }

                    Rectangle {
                        id: panicDetails
                        Layout.fillWidth: true
                        Layout.leftMargin: 32
                        Layout.rightMargin: 32
                        Layout.topMargin: 8
                        visible: panicPage.details
                        implicitHeight: reason.implicitHeight + report.implicitHeight + 44
                        radius: M3.classic ? M3.cornerCard : 20
                        color: M3.surfaceContainerHigh

                        MText {
                            id: reason
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 16
                            role: "titleSmall"
                            color: M3.error
                            wrapMode: Text.Wrap
                            text: app.panic.reason || ""
                        }
                        TextEdit {
                            id: report
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: reason.bottom
                            anchors.margins: 16
                            anchors.topMargin: 12
                            readOnly: true
                            selectByMouse: true
                            wrapMode: TextEdit.Wrap
                            font.family: "monospace"
                            font.pointSize: 9
                            color: M3.surfaceContent
                            selectionColor: M3.primaryContainer
                            selectedTextColor: M3.primaryContainerContent
                            text: String(app.panic.log || "").length > 0
                                ? app.panic.log
                                : i18n("Only an administrator can read the full report.")
                        }
                    }
                }
            }

            RowLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 24
                spacing: 8

                QQC2.Button {
                    text: panicPage.details ? i18n("Hide details") : i18n("Details")
                    flat: true
                    onClicked: panicPage.details = !panicPage.details
                }
                QQC2.Button {
                    visible: panicPage.details
                    text: i18n("Copy")
                    icon.name: "edit-copy"
                    flat: true
                    onClicked: {
                        report.selectAll();
                        report.copy();
                        report.deselect();
                    }
                }
                Item { Layout.fillWidth: true }
                QQC2.Button {
                    text: i18n("Okay")
                    highlighted: true
                    onClicked: Qt.quit()
                }
            }
        }
    }

    component WallpaperChoice: QQC2.AbstractButton {
        id: tile
        property string title
        property url preview
        property url scene
        readonly property bool live: scene.toString().length > 0
        property bool selected: false
        implicitHeight: thumb.height + 36
        Accessible.name: title
        background: Item {}
        contentItem: ColumnLayout {
            spacing: 6
            RoundedClip {
                id: thumb
                Layout.fillWidth: true
                Layout.preferredHeight: width * 0.62
                radius: M3.classic ? M3.cornerImage : 18 + 10 * selectMorph.value
                MMorph {
                    id: selectMorph
                    active: tile.selected
                    dampingRatio: M3.springExpressiveDefaultDamping
                    response: M3.springExpressiveDefaultResponse
                }
                Rectangle { anchors.fill: parent; color: tile.live ? M3.darkScheme.surface : M3.surfaceContainerHigh }
                Image {
                    anchors.fill: parent
                    visible: !tile.live
                    source: tile.preview
                    sourceSize: Qt.size(360, 224)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                Loader {
                    active: tile.live
                    width: 960
                    height: 600
                    scale: thumb.width / 960
                    transformOrigin: Item.TopLeft
                    source: tile.scene
                    onLoaded: {
                        item.intro = 1;
                        item.phase = 0.3;
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: thumb.radius
                    color: "transparent"
                    border.width: tile.selected ? 3 : 0
                    border.color: M3.primary
                }
                MStateLayer {
                    radius: thumb.radius
                    hovered: tile.hovered
                    pressed: tile.pressed
                }
            }
            MText { Layout.fillWidth: true; role: "labelLarge"; text: tile.title }
        }
    }
}
