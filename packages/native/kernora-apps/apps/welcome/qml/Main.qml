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

AppWindow {
    id: app

    width: 900
    height: 640
    minimumWidth: 560
    minimumHeight: 520
    color: M3.surfaceContainer
    visible: !(firstRun && SystemInfo.live)
    title: i18n("Welcome")

    property int page: 0
    readonly property int pages: 6

    ConfigEntry {
        id: showOnLogin
        file: "kernora-welcomerc"
        group: "General"
        key: "ShowOnLogin"
        defaultValue: true
    }

    function finish(): void {
        showOnLogin.value = false;
        Qt.quit();
    }
    function handleArguments(args: var): void {}

    readonly property bool firstRun: (startArguments || []).indexOf("--first-run") >= 0
    Component.onCompleted: {
        if (firstRun && SystemInfo.live) {
            Qt.quit();
        }
    }

    Shortcut { sequences: ["Right", "PgDown"]; onActivated: app.page = Math.min(app.pages - 1, app.page + 1) }
    Shortcut { sequences: ["Left", "PgUp"]; onActivated: app.page = Math.max(0, app.page - 1) }
    Shortcut { sequence: "Escape"; onActivated: app.finish() }

    RoundedClip {
        anchors.fill: parent
        anchors.margins: 12
        radius: M3.classic ? M3.cornerCard : 28

        Rectangle {
            anchors.fill: parent
            color: M3.surface
        }

        Item {
            id: viewport
            anchors.fill: parent
            anchors.bottomMargin: 88

            Repeater {
                model: [hello, theme, style, wallpaper, apps, done]
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
                    title: i18n("Quick settings are on the right of the panel")
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
                radius: M3.classic ? M3.cornerImage : tile.selected ? 28 : 18
                Behavior on radius { NumberAnimation { duration: M3.durationMedium2 } }
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
                    radius: parent.radius
                    color: "transparent"
                    border.width: tile.selected ? 3 : 0
                    border.color: M3.primary
                }
                MStateLayer {
                    radius: parent.radius
                    hovered: tile.hovered
                    pressed: tile.pressed
                }
            }
            MText { Layout.fillWidth: true; role: "labelLarge"; text: tile.title }
        }
    }
}
