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
    visible: !(firstRun && SystemInfo.live) && !(whatsNew && notes.length === 0) && !(kernelPanic && !panic.id)
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
    function handleArguments(args: var): void {}

    readonly property bool firstRun: (startArguments || []).indexOf("--first-run") >= 0
    readonly property bool whatsNew: (startArguments || []).indexOf("--whats-new") >= 0
    readonly property bool kernelPanic: (startArguments || []).indexOf("--kernel-panic") >= 0
    readonly property bool special: whatsNew || kernelPanic
    readonly property var panic: kernelPanic ? SystemInfo.kernelPanic() : ({})
    property var notes: []
    property bool heroDone: false
    readonly property bool heroActive: whatsNew && !heroDone && notes.length > 0 && notes[0].hero === "ked2"

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
            active: app.heroActive
            sourceComponent: ked2View
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

    component TourBackdrop: Item {
        id: backdrop
        property url image
        property url scene
        property bool dim: false
        clip: true
        Rectangle {
            anchors.fill: parent
            color: M3.tertiaryContainer
        }
        Image {
            anchors.fill: parent
            visible: backdrop.image.toString().length > 0
            source: backdrop.image
            sourceSize: Qt.size(1200, 800)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        Loader {
            active: backdrop.scene.toString().length > 0
            width: 960
            height: 600
            scale: Math.max(backdrop.width / 960, backdrop.height / 600)
            transformOrigin: Item.TopLeft
            source: backdrop.scene
            onLoaded: {
                item.intro = 1;
                item.phase = 0.35;
            }
        }
        Rectangle {
            anchors.fill: parent
            visible: backdrop.dim
            color: Qt.rgba(0, 0, 0, M3.dark ? 0.55 : 0.0)
        }
    }

    component TourStatusBar: Item {
        id: statusBar
        height: 36
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 72
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.32) }
                GradientStop { position: 1; color: "transparent" }
            }
        }
        Text {
            x: 18
            anchors.verticalCenter: parent.verticalCenter
            color: "white"
            font.family: M3.labelLarge.family
            font.pixelSize: 14
            font.weight: Font.Medium
            renderType: Text.QtRendering
            text: Qt.formatTime(new Date(), Qt.locale().timeFormat(Locale.ShortFormat)) + "   " + Qt.locale().toString(new Date(), "ddd, d MMM")
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12
            MIcon {
                anchors.verticalCenter: parent.verticalCenter
                size: 18
                source: "notifications"
                color: "white"
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: chipRow.width + 20
                height: 26
                radius: 13
                color: Qt.rgba(0, 0, 0, 0.42)
                Row {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: 8
                    MIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        size: 16
                        source: "kernora-bar-wifi-4"
                        color: "white"
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30
                        height: 16
                        radius: 8
                        color: "white"
                        Text {
                            anchors.centerIn: parent
                            color: "black"
                            font.family: M3.labelSmall.family
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            renderType: Text.QtRendering
                            text: "82"
                        }
                    }
                }
            }
        }
    }

    component TourTaskbar: Rectangle {
        id: taskbar
        property bool menuOpen: false
        property var apps: []
        height: 52
        color: M3.dark ? M3.surfaceContainer : "white"
        Rectangle {
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 66
            height: 36
            radius: 18
            color: taskbar.menuOpen ? M3.primary : M3.surfaceContainerHigh
            MIcon {
                anchors.centerIn: parent
                size: 20
                source: "kernora-logo"
                color: taskbar.menuOpen ? M3.primaryContent : M3.surfaceVariantContent
            }
        }
        Row {
            anchors.centerIn: parent
            spacing: 10
            Repeater {
                model: taskbar.apps.slice(0, 6)
                delegate: AppIcon {
                    required property var modelData
                    size: 32
                    name: modelData.icon
                }
            }
        }
    }

    component TourWindow: Item {
        id: win
        property string title
        property string icon
        default property alias contents: body.data
        Kirigami.ShadowedRectangle {
            anchors.fill: parent
            radius: 12
            color: M3.surface
            shadow.size: 26
            shadow.yOffset: 8
            shadow.color: Qt.rgba(0, 0, 0, M3.dark ? 0.45 : 0.22)
            border.width: M3.dark ? 1 : 0
            border.color: Qt.rgba(1, 1, 1, 0.12)
        }
        RoundedClip {
            anchors.fill: parent
            radius: 12
            Rectangle {
                id: titleBar
                width: parent.width
                height: 34
                color: M3.surfaceContainer
                AppIcon {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    size: 18
                    name: win.icon
                }
                Text {
                    x: 38
                    anchors.verticalCenter: parent.verticalCenter
                    color: M3.surfaceContent
                    font.family: M3.titleSmall.family
                    font.pixelSize: 13
                    renderType: Text.QtRendering
                    text: win.title
                }
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 14
                    Repeater {
                        model: ["window-minimize", "window-maximize", "window-close"]
                        delegate: MIcon {
                            required property string modelData
                            size: 15
                            source: modelData
                            color: M3.surfaceVariantContent
                        }
                    }
                }
            }
            Item {
                id: body
                anchors.fill: parent
                anchors.topMargin: titleBar.height
            }
        }
    }

    Component {
        id: ked2View
        Item {
            id: tour

            property int page: 0
            readonly property int count: 6
            function next(): void {
                if (page < count - 1) {
                    page += 1;
                } else {
                    Qt.quit();
                }
            }
            function previous(): void {
                page = Math.max(0, page - 1);
            }

            Shortcut { sequences: ["Right", "PgDown"]; onActivated: tour.next() }
            Shortcut { sequences: ["Left", "PgUp"]; onActivated: tour.previous() }

            readonly property var texts: [
                { title: i18n("Meet KED 2"), text: i18n("Kernora Expressive Design 2 is Kernora's new look, inspired by Googlebook. Here is what changed.") },
                { title: i18n("Status bar at the top"), text: i18n("The time and date sit on the left, notifications, the network and the battery on the right. The bar stays clear and follows your wallpaper.") },
                { title: i18n("A new apps menu"), text: i18n("It opens in the middle above the taskbar. All apps from A to Z, and search finds apps, settings, files and the web.") },
                { title: i18n("Quick settings"), text: i18n("Big sliders and tiles in two columns. Click a tile's icon to turn it on, or its name for details.") },
                { title: i18n("Rounded windows"), text: i18n("Every corner of a window is rounded, with a soft shadow around it. Maximised windows stay square.") },
                { title: i18n("Wallpaper collections"), text: i18n("Landscapes, Earth, Art and more, sorted into collections in Wallpaper & style.") }
            ]

            readonly property var apps: {
                const ids = ["librewolf", "org.kernora.files", "org.kernora.store", "org.kernora.settings", "org.kernora.photos",
                             "org.kernora.player", "org.kernora.calculator", "org.kernora.editor", "org.kernora.screenshot",
                             "org.kernora.taskmanager", "org.kernora.drivers", "org.kernora.quickshare"];
                const list = [];
                for (const id of ids) {
                    const info = Process.application(id);
                    if (info && info.name) {
                        list.push({ id: id, name: info.name, icon: info.icon || id });
                    }
                }
                return list;
            }

            readonly property var wallpapers: Files.wallpapers()
            readonly property var collections: {
                const order = ["landscapes", "earth", "art", "curated", "life", "solid-colors", "culture", "motif", "textures"];
                const result = [];
                for (const id of order) {
                    const items = wallpapers.filter(w => w.category === id);
                    if (items.length > 0) {
                        result.push({ id: id, items: items });
                    }
                }
                return result;
            }
            function collectionName(id: string): string {
                return ({
                    "landscapes": i18n("Landscapes"), "earth": i18n("Earth"), "art": i18n("Art"), "curated": i18n("Curated"),
                    "life": i18n("Life"), "solid-colors": i18n("Solid colours"), "culture": i18n("Culture"),
                    "motif": i18n("Motif"), "textures": i18n("Textures")
                })[id] || id;
            }

            property url backdropImage
            property url backdropScene
            Component.onCompleted: {
                const appletsrc = "plasma-org.kde.plasma.desktop-appletsrc";
                for (const id of Config.groupList(appletsrc, "Containments")) {
                    const group = "Containments/" + id;
                    const plugin = Config.read(appletsrc, group, "wallpaperplugin", "");
                    const containment = Config.read(appletsrc, group, "plugin", "");
                    if (plugin.length === 0 || (containment !== "org.kde.desktopcontainment" && containment !== "org.kde.plasma.folder")) {
                        continue;
                    }
                    if (plugin === "org.kde.image") {
                        const stored = String(Config.read(appletsrc, group + "/Wallpaper/org.kde.image/General", "Image", "")).replace(/\/$/, "");
                        if (stored.length === 0) {
                            continue;
                        }
                        const match = wallpapers.find(w => String(w.image) === stored || String(w.image).indexOf(stored + "/") === 0);
                        backdropImage = match ? match.preview : stored;
                    } else {
                        backdropScene = "file:///usr/share/plasma/wallpapers/" + plugin + "/contents/ui/Scene.qml";
                    }
                    break;
                }
                if (backdropImage.toString().length === 0 && backdropScene.toString().length === 0) {
                    backdropScene = "file:///usr/share/plasma/wallpapers/org.kernora.shapes/contents/ui/Scene.qml";
                }
            }

            Rectangle {
                anchors.fill: parent
                color: M3.surfaceContainerLow
            }

            Item {
                id: viewport
                anchors.fill: parent
                anchors.bottomMargin: 96
                clip: true

                Row {
                    x: -tour.page * viewport.width
                    Behavior on x {
                        NumberAnimation {
                            duration: M3.motionScale > 0 ? 550 : 0
                            easing.type: Easing.Bezier
                            easing.bezierCurve: M3.easingEmphasizedDecelerate
                        }
                    }

                    Repeater {
                        model: tour.count
                        delegate: Item {
                            id: slide
                            required property int index
                            width: viewport.width
                            height: viewport.height

                            RoundedClip {
                                id: art
                                x: 24
                                y: 24
                                width: slide.width - 48
                                height: slide.height - 190
                                radius: 28
                                Loader {
                                    anchors.fill: parent
                                    sourceComponent: [overviewArt, statusArt, menuArt, quickArt, windowsArt, wallsArt][slide.index]
                                }
                            }

                            Text {
                                id: heading
                                x: 48
                                anchors.top: art.bottom
                                anchors.topMargin: 28
                                width: slide.width - 96
                                color: M3.surfaceContent
                                font.family: M3.displaySmall.family
                                font.pixelSize: slide.index === 0 ? 44 : M3.headlineLarge.pixelSize
                                font.weight: slide.index === 0 ? Font.Medium : Font.Normal
                                renderType: Text.QtRendering
                                elide: Text.ElideRight
                                text: tour.texts[slide.index].title
                            }
                            MText {
                                x: 48
                                anchors.top: heading.bottom
                                anchors.topMargin: 10
                                width: Math.min(slide.width - 96, 640)
                                role: "bodyLarge"
                                color: M3.surfaceVariantContent
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                text: tour.texts[slide.index].text
                            }
                        }
                    }
                }
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 48
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 46
                spacing: 6
                Repeater {
                    model: tour.count
                    delegate: Rectangle {
                        required property int index
                        anchors.verticalCenter: parent.verticalCenter
                        width: index === tour.page ? 26 : 8
                        height: 8
                        radius: 4
                        color: index === tour.page ? M3.primary : M3.outlineVariant
                        Behavior on width {
                            NumberAnimation {
                                duration: M3.motionScale > 0 ? 300 : 0
                                easing.type: Easing.Bezier
                                easing.bezierCurve: M3.easingEmphasizedDecelerate
                            }
                        }
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 40
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 32
                spacing: 8
                MButton {
                    variant: tour.page === tour.count - 1 ? "tonal" : "text"
                    text: tour.page === tour.count - 1 ? i18n("All changes") : i18n("Skip")
                    onClicked: {
                        if (tour.page === tour.count - 1) {
                            app.heroDone = true;
                        } else {
                            Qt.quit();
                        }
                    }
                }
                MButton {
                    text: tour.page === tour.count - 1 ? i18n("Get started") : i18n("Next")
                    onClicked: tour.next()
                }
            }

            Component {
                id: overviewArt
                Item {
                    TourBackdrop {
                        anchors.fill: parent
                        image: tour.backdropImage
                        scene: tour.backdropScene
                    }
                    TourStatusBar {
                        width: parent.width
                    }
                    TourTaskbar {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        apps: tour.apps
                    }
                }
            }

            Component {
                id: statusArt
                Item {
                    TourBackdrop {
                        anchors.fill: parent
                        image: tour.backdropImage
                        scene: tour.backdropScene
                    }
                    TourStatusBar {
                        width: parent.width / 1.6
                        scale: 1.6
                        transformOrigin: Item.TopLeft
                    }
                }
            }

            Component {
                id: menuArt
                Item {
                    TourBackdrop {
                        anchors.fill: parent
                        image: tour.backdropImage
                        scene: tour.backdropScene
                        dim: true
                    }
                    TourStatusBar {
                        width: parent.width
                    }
                    Rectangle {
                        id: sheet
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: dock.top
                        anchors.bottomMargin: 10
                        width: 470
                        height: parent.height - 36 - 52 - 22
                        radius: 28
                        color: M3.dark ? M3.surfaceContainerHigh : M3.surfaceContainerLow
                        Rectangle {
                            id: searchPill
                            x: 22
                            y: 22
                            width: parent.width - 44
                            height: 44
                            radius: 22
                            color: M3.dark ? M3.surfaceContainer : M3.surfaceContainerLowest
                            AppIcon {
                                x: 14
                                anchors.verticalCenter: parent.verticalCenter
                                size: 22
                                name: "librewolf"
                            }
                            Text {
                                x: 48
                                anchors.verticalCenter: parent.verticalCenter
                                color: M3.surfaceVariantContent
                                font.family: M3.bodyLarge.family
                                font.pixelSize: 15
                                renderType: Text.QtRendering
                                text: i18n("Search web and more")
                            }
                        }
                        Grid {
                            anchors.top: searchPill.bottom
                            anchors.topMargin: 16
                            anchors.horizontalCenter: parent.horizontalCenter
                            columns: 6
                            columnSpacing: 0
                            rowSpacing: 8
                            Repeater {
                                model: tour.apps.slice(0, 12)
                                delegate: Column {
                                    required property var modelData
                                    width: 70
                                    spacing: 6
                                    AppIcon {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        size: 40
                                        name: modelData.icon
                                    }
                                    Text {
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                        color: M3.surfaceContent
                                        font.family: M3.bodySmall.family
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                        renderType: Text.QtRendering
                                        text: modelData.name
                                    }
                                }
                            }
                        }
                    }
                    TourTaskbar {
                        id: dock
                        anchors.bottom: parent.bottom
                        width: parent.width
                        apps: tour.apps
                        menuOpen: true
                    }
                }
            }

            Component {
                id: quickArt
                Item {
                    id: quickScene
                    property bool wifi: true
                    property bool bt: false
                    property bool dnd: false
                    TourBackdrop {
                        anchors.fill: parent
                        image: tour.backdropImage
                        scene: tour.backdropScene
                    }
                    TourStatusBar {
                        width: parent.width
                    }
                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        y: 42
                        width: 448
                        height: quickColumn.implicitHeight + 32
                        radius: 28
                        color: M3.surfaceContainerHigh
                        Column {
                            id: quickColumn
                            x: 16
                            y: 16
                            width: parent.width - 32
                            spacing: 10
                            MSlider {
                                width: parent.width
                                googlebook: true
                                trackHeight: 40
                                icon: "kernora-brightness"
                                text: i18n("Brightness")
                                from: 0
                                to: 100
                                value: 70
                            }
                            MSlider {
                                width: parent.width
                                googlebook: true
                                trackHeight: 40
                                icon: "audio-volume-high"
                                text: i18n("Volume")
                                from: 0
                                to: 100
                                value: 45
                            }
                            Grid {
                                columns: 2
                                columnSpacing: 8
                                rowSpacing: 8
                                MTile {
                                    width: (quickColumn.width - 8) / 2
                                    googlebook: true
                                    icon: "network-wireless"
                                    title: i18n("Wi-Fi")
                                    subtitle: quickScene.wifi ? i18n("Connected") : i18n("Off")
                                    checked: quickScene.wifi
                                    hasDetails: true
                                    onToggled: quickScene.wifi = !quickScene.wifi
                                }
                                MTile {
                                    width: (quickColumn.width - 8) / 2
                                    googlebook: true
                                    icon: quickScene.bt ? "bluetooth" : "bluetooth-disabled"
                                    iconOn: "kernora-tile-bluetooth-on"
                                    title: i18n("Bluetooth")
                                    subtitle: quickScene.bt ? i18n("On") : i18n("Off")
                                    checked: quickScene.bt
                                    hasDetails: true
                                    onToggled: quickScene.bt = !quickScene.bt
                                }
                                MTile {
                                    width: (quickColumn.width - 8) / 2
                                    googlebook: true
                                    icon: "kernora-tile-darktheme"
                                    title: i18n("Dark theme")
                                    checked: M3.dark
                                }
                                MTile {
                                    width: (quickColumn.width - 8) / 2
                                    googlebook: true
                                    icon: "dnd"
                                    iconOn: "kernora-tile-dnd-on"
                                    title: i18n("Do Not Disturb")
                                    checked: quickScene.dnd
                                    onToggled: quickScene.dnd = !quickScene.dnd
                                }
                            }
                        }
                    }
                }
            }

            Component {
                id: windowsArt
                Item {
                    TourBackdrop {
                        anchors.fill: parent
                        image: tour.backdropImage
                        scene: tour.backdropScene
                    }
                    TourStatusBar {
                        width: parent.width
                    }
                    TourWindow {
                        x: 70
                        y: 58
                        width: 400
                        height: 250
                        title: i18n("Files")
                        icon: "org.kernora.files"
                        Column {
                            x: 8
                            y: 10
                            width: parent.width - 16
                            Repeater {
                                model: [
                                    { icon: "folder-download", title: i18n("Downloads") },
                                    { icon: "folder-documents", title: i18n("Documents") },
                                    { icon: "folder-pictures", title: i18n("Pictures") }
                                ]
                                delegate: ListItem {
                                    required property var modelData
                                    width: parent.width
                                    title: modelData.title
                                    icon: modelData.icon
                                    iconStyle: "plain"
                                    interactive: false
                                }
                            }
                        }
                    }
                    TourWindow {
                        x: parent.width - 470
                        y: 104
                        width: 420
                        height: 250
                        title: i18n("Settings")
                        icon: "org.kernora.settings"
                        Column {
                            x: 8
                            y: 10
                            width: parent.width - 16
                            Repeater {
                                model: [
                                    { icon: "network-wireless", title: i18n("Network & internet"), accent: 0 },
                                    { icon: "bluetooth", title: i18n("Bluetooth"), accent: 1 },
                                    { icon: "preferences-desktop-wallpaper", title: i18n("Wallpaper & style"), accent: 4 }
                                ]
                                delegate: ListItem {
                                    required property var modelData
                                    width: parent.width
                                    title: modelData.title
                                    icon: modelData.icon
                                    accent: modelData.accent
                                    interactive: false
                                }
                            }
                        }
                    }
                    TourTaskbar {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        apps: tour.apps
                    }
                }
            }

            Component {
                id: wallsArt
                Rectangle {
                    color: M3.surfaceContainerHigh
                    Grid {
                        anchors.centerIn: parent
                        columns: 3
                        columnSpacing: 14
                        rowSpacing: 10
                        Repeater {
                            model: tour.collections.slice(0, 6)
                            delegate: Column {
                                id: collection
                                required property var modelData
                                spacing: 6
                                RoundedClip {
                                    width: 200
                                    height: 112
                                    radius: 18
                                    Image {
                                        anchors.fill: parent
                                        source: collection.modelData.items[0].preview
                                        sourceSize: Qt.size(400, 224)
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                    }
                                }
                                Text {
                                    color: M3.surfaceContent
                                    font.family: M3.titleSmall.family
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    renderType: Text.QtRendering
                                    text: tour.collectionName(collection.modelData.id)
                                }
                            }
                        }
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
