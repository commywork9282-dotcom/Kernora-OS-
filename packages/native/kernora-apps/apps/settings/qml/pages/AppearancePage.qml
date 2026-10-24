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
import "../components"

SettingsPage {
    id: page

    title: i18n("Wallpaper & style")

    readonly property bool dark: Appearance.dark

    function setDark(enable: bool): void {
        if (enable !== dark && !Appearance.busy) {
            Appearance.setDark(enable, ok => {
                if (!ok) {
                    page.notify(i18n("The theme could not be changed."));
                }
            });
        }
    }

    readonly property string generation: Appearance.generation

    function setGeneration(value: string): void {
        if (value !== generation && !Appearance.busy) {
            Appearance.setGeneration(value, ok => {
                if (!ok) {
                    page.notify(i18n("The style could not be changed."));
                }
            });
        }
    }

    readonly property string colour: Appearance.colour
    readonly property var colours: Appearance.colours()

    function setColour(value: string): void {
        if (value !== colour && !Appearance.busy) {
            Appearance.setColour(value, ok => {
                if (!ok) {
                    page.notify(i18n("The colour could not be changed."));
                }
            });
        }
    }

    readonly property string appletsrc: "plasma-org.kde.plasma.desktop-appletsrc"
    property string wallpaperPlugin: ""
    property string wallpaperImage: ""
    readonly property var liveWallpapers: Files.liveWallpapers()
    readonly property var currentLive: liveWallpapers.find(w => w.id === wallpaperPlugin) || null
    readonly property bool live: currentLive !== null
    property var wallpapers: Files.wallpapers()

    function isDesktop(group: string): bool {
        const containment = Config.read(appletsrc, group, "plugin", "");
        return containment === "org.kde.desktopcontainment" || containment === "org.kde.plasma.folder";
    }
    function readWallpaper(): void {
        for (const id of Config.groupList(appletsrc, "Containments")) {
            const group = "Containments/" + id;
            const plugin = Config.read(appletsrc, group, "wallpaperplugin", "");
            if (plugin.length === 0 || !isDesktop(group)) {
                continue;
            }
            wallpaperPlugin = plugin;
            wallpaperImage = Config.read(appletsrc, group + "/Wallpaper/org.kde.image/General", "Image", "");
            return;
        }
        wallpaperPlugin = "org.kernora.shapes";
    }
    Component.onCompleted: {
        readWallpaper();
        updatePanelOpacity("");
    }

    property bool panelBusy: false
    property bool panelAvailable: false
    property bool panelTranslucent: false

    function updatePanelOpacity(mode: string): void {
        if (panelBusy) {
            return;
        }
        panelBusy = true;
        const script = "var items = panels(); "
            + (mode ? "items.forEach(function (panel) { panel.opacity = " + JSON.stringify(mode) + "; }); " : "")
            + "print(JSON.stringify(items.map(function (panel) { return panel.opacity; })));";
        DBus.call("session", "org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell", "evaluateScript",
                  [{ type: "s", value: script }], (ok, result) => {
            page.panelBusy = false;
            let modes = [];
            if (ok) {
                try {
                    modes = JSON.parse(String(result).trim());
                    ok = Array.isArray(modes) && modes.every(value => ["opaque", "translucent", "adaptive"].includes(value));
                } catch (error) {
                    ok = false;
                }
            }
            page.panelAvailable = ok && modes.length > 0;
            if (page.panelAvailable) {
                page.panelTranslucent = modes.every(value => value === "translucent");
            }
            if (mode && (!page.panelAvailable || modes.some(value => value !== mode))) {
                page.notify(i18n("The panel transparency could not be changed."));
            }
        });
    }

    onVisibleChanged: {
        if (visible) {
            updatePanelOpacity("");
        }
    }

    function sameImage(a: string, b: string): bool {
        const strip = s => String(s).replace(/^file:\/\//, "");
        return strip(a) === strip(b);
    }

    ConfigEntry {
        id: lockPlugin
        file: "kscreenlockerrc"
        group: "Greeter"
        key: "WallpaperPlugin"
        defaultValue: ""
    }
    readonly property bool lockScreenToo: live ? lockPlugin.value === wallpaperPlugin : lockPlugin.value === "org.kde.image"

    function syncGreeter(): void {
        if (Accounts.administrator) {
            Files.syncGreeterBackground(live ? wallpaperPlugin : "org.kde.image", live ? "" : wallpaperImage);
        }
    }

    function chooseImage(url: url): void {
        const follow = lockScreenToo;
        Files.setWallpaper(url);
        wallpaperPlugin = "org.kde.image";
        wallpaperImage = String(url);
        if (follow) {
            Files.setLockScreenWallpaper(url);
        }
        syncGreeter();
    }
    function chooseLive(plugin: string): void {
        const follow = lockScreenToo;
        Files.setLiveWallpaper(plugin);
        wallpaperPlugin = plugin;
        if (follow) {
            Files.setLockScreenPlugin(plugin);
        }
        syncGreeter();
    }

    function setLiveOption(key: string, value: var): void {
        const plugin = wallpaperPlugin;
        const literal = typeof value === "string" ? "'" + value + "'" : String(value);
        DBus.call("session", "org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell", "evaluateScript",
                  [{ type: "s", value: "for (const d of desktops()) { if (d.wallpaperPlugin !== '" + plugin + "') continue; "
                      + "d.currentConfigGroup = ['Wallpaper', '" + plugin + "', 'General']; d.writeConfig('" + key + "', " + literal + "); }" }],
                  null);
    }
    function liveOption(key: string, fallback: var): var {
        for (const id of Config.groupList(appletsrc, "Containments")) {
            if (!isDesktop("Containments/" + id)) {
                continue;
            }
            const value = Config.read(appletsrc, "Containments/" + id + "/Wallpaper/" + wallpaperPlugin + "/General", key, null);
            if (value !== null && value !== undefined && value !== "") {
                return value;
            }
        }
        return fallback;
    }

    hero: Component {
        RoundedClip {
            id: preview
            width: parent ? parent.width : 0
            height: Math.round(width * 0.46)
            radius: M3.classic ? M3.cornerCard : 28

            Rectangle {
                anchors.fill: parent
                color: M3.surfaceContainerHigh
            }

            property real phase: 0.1
            NumberAnimation on phase {
                running: page.live && page.visible && M3.motionScale > 0
                from: 0.1
                to: 1.1
                duration: 240000
                loops: Animation.Infinite
            }
            Loader {
                anchors.fill: parent
                active: page.live
                source: page.live ? page.currentLive.scene : ""
                onLoaded: {
                    item.intro = 1;
                    item.phase = Qt.binding(() => preview.phase % 1);
                }
            }
            Image {
                anchors.fill: parent
                visible: !page.live
                source: page.live ? "" : page.wallpaperImage
                sourceSize: Qt.size(width * 2, height * 2)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }
    }

    Group {
        title: i18n("Theme")

        ListItem {
            title: i18n("Dark theme")
            subtitle: Appearance.busy ? i18n("Applying…") : i18n("Dark backgrounds for the system and apps")
            icon: "night-light"
            iconStyle: "plain"
            checkable: true
            checked: page.dark
            enabled: !Appearance.busy
            onToggled: on => page.setDark(on)
        }
    }

    ConfigEntry {
        id: themedApps
        file: "kernorarc"
        group: "Icons"
        key: "themedApps"
        defaultValue: true
    }

    Group {
        title: i18n("App icons")

        ListItem {
            title: i18n("Match app icons to the system colour")
            subtitle: i18n("Includes newly installed apps. Original icons return when turned off.")
            icon: "preferences-desktop-icons"
            iconStyle: "plain"
            checkable: true
            checked: Boolean(themedApps.value)
            onToggled: on => themedApps.value = on
        }
    }

    Group {
        title: i18n("Colour")
        note: Appearance.busy ? i18n("Applying…") : i18n("Apps, the panel, windows and the live wallpapers take on the chosen colour.")

        Flow {
            width: parent.width
            spacing: 12

            Repeater {
                model: page.colours
                delegate: ColourSwatch {
                    required property var modelData
                    swatch: page.dark ? modelData.dark : modelData.light
                    name: modelData.name
                    selected: page.colour === modelData.id
                    enabled: !Appearance.busy
                    onClicked: page.setColour(modelData.id)
                }
            }
        }
    }

    Group {
        title: i18n("Style")
        note: i18n("Shapes, depth, buttons and the quick settings follow the chosen generation of Material.")

        ChoiceItem {
            title: i18n("Interface style")
            icon: "preferences-desktop-plasma-theme"
            iconStyle: "plain"
            enabled: !Appearance.busy
            options: [
                { value: "md3", label: "Material 3", description: i18n("2021 · Material You") },
                { value: "md2", label: "Material Design 2", description: i18n("2018 · Material Theming") },
                { value: "md1", label: "Material Design 1", description: i18n("2014 · paper and ink") }
            ]
            currentValue: page.generation
            subtitle: {
                if (Appearance.busy) {
                    return i18n("Applying…");
                }
                const option = options.find(o => o.value === currentValue);
                return option ? option.label : "";
            }
            onSelected: value => page.setGeneration(value)
        }
    }

    Group {
        title: i18n("Panel")
        note: i18n("Applies to all panels. The shape and colour follow the system style.")

        ListItem {
            title: i18n("Transparent panel")
            subtitle: page.panelBusy ? i18n("Applying…") : i18n("Let the wallpaper show through a softly tinted background")
            icon: "preferences-desktop-plasma-theme"
            iconStyle: "plain"
            checkable: true
            checked: page.panelTranslucent
            enabled: page.panelAvailable && !page.panelBusy && !Appearance.busy
            onToggled: on => page.updatePanelOpacity(on ? "translucent" : "opaque")
        }
    }

    Group {
        title: i18n("Wallpaper")

        GridLayout {
            width: parent.width
            columns: Math.max(2, Math.floor(width / 190))
            columnSpacing: 12
            rowSpacing: 12

            Repeater {
                model: page.liveWallpapers
                delegate: WallpaperTile {
                    required property var modelData
                    Layout.fillWidth: true
                    title: modelData.name
                    subtitle: i18n("Live")
                    scene: modelData.scene
                    selected: page.wallpaperPlugin === modelData.id
                    onClicked: page.chooseLive(modelData.id)
                }
            }
            Repeater {
                model: page.wallpapers
                delegate: WallpaperTile {
                    required property var modelData
                    Layout.fillWidth: true
                    title: modelData.name
                    preview: modelData.preview
                    selected: !page.live && page.sameImage(page.wallpaperImage, modelData.image)
                    onClicked: page.chooseImage(modelData.image)
                }
            }
            WallpaperTile {
                Layout.fillWidth: true
                title: i18n("Your picture")
                subtitle: i18n("Choose…")
                addTile: true
                selected: !page.live && !page.wallpapers.some(w => page.sameImage(page.wallpaperImage, w.image))
                preview: selected ? page.wallpaperImage : ""
                onClicked: pictureDialog.open()
            }
        }

        Item { width: 1; height: 8 }

        ListItem {
            title: i18n("Use on the lock screen too")
            icon: "system-lock-screen"
            iconStyle: "plain"
            checkable: true
            checked: page.lockScreenToo
            onToggled: on => {
                if (!on) {
                    Files.setLockScreenWallpaper("");
                } else if (page.live) {
                    Files.setLockScreenPlugin(page.wallpaperPlugin);
                } else {
                    Files.setLockScreenWallpaper(page.wallpaperImage);
                }
            }
        }
    }

    Group {
        title: page.live ? page.currentLive.name : ""
        visible: page.live

        SliderItem {
            title: i18n("Speed")
            startIcon: "media-playback-pause"
            endIcon: "media-seek-forward"
            from: 0.25
            to: 2
            stepSize: 0.25
            value: Number(page.liveOption("Speed", 1))
            formatValue: v => v === 1 ? i18n("Normal") : i18n("%1×", v.toLocaleString(Qt.locale(), "f", 2).replace(/0+$/, "").replace(/[.,]$/, ""))
            onMoved: value => page.setLiveOption("Speed", value)
        }
        ListItem {
            visible: page.wallpaperPlugin === "org.kernora.shapes"
            title: i18n("Changing colours")
            subtitle: i18n("The shapes slowly move through the palette")
            icon: "color-picker"
            iconStyle: "plain"
            checkable: true
            property bool on: String(page.liveOption("ColourCycle", true)) !== "false"
            checked: on
            onToggled: value => {
                on = value;
                page.setLiveOption("ColourCycle", value);
            }
        }
        ListItem {
            title: i18n("Pause behind windows")
            subtitle: i18n("Saves power while a maximised window covers the desktop")
            icon: "battery-profile-powersave"
            iconStyle: "plain"
            checkable: true
            property bool on: String(page.liveOption("PauseWhenCovered", true)) !== "false"
            checked: on
            onToggled: value => {
                on = value;
                page.setLiveOption("PauseWhenCovered", value);
            }
        }
    }

    ConfigEntry {
        id: fontEntry
        file: "kdeglobals"
        group: "General"
        key: "font"
        defaultValue: "Roboto,10.5,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
    }
    readonly property real fontSize: {
        const size = parseFloat(String(fontEntry.value).split(",")[1]);
        return isNaN(size) ? 10.5 : size;
    }

    function fontString(size: real, weight: int): string {
        const family = String(fontEntry.value).split(",")[0] || "Roboto";
        return family + "," + size + ",-1,5," + weight + ",0,0,0,0,0,0,0,0,0,0,1";
    }
    function setFontSize(size: real): void {
        const small = size - 1.5;
        Config.write("kdeglobals", "General", "font", fontString(size, 400), true);
        Config.write("kdeglobals", "General", "menuFont", fontString(size, 400), true);
        Config.write("kdeglobals", "General", "toolBarFont", fontString(small, 400), true);
        Config.write("kdeglobals", "General", "smallestReadableFont", fontString(small, 400), true);
        Config.write("kdeglobals", "WM", "activeFont", fontString(size, 500), true);
        DBus.emitSignal("session", "/KGlobalSettings", "org.kde.KGlobalSettings", "notifyChange",
                        [{ type: "i", value: 1 }, { type: "i", value: 0 }]);
        DBus.call("session", "org.kde.KWin", "/KWin", "org.kde.KWin", "reconfigure", [], null);
    }

    ConfigEntry {
        id: animationFactor
        file: "kdeglobals"
        group: "KDE"
        key: "AnimationDurationFactor"
        defaultValue: 1
    }

    Group {
        title: i18n("Text and motion")

        ChoiceItem {
            title: i18n("Text size")
            icon: "preferences-desktop-font"
            accent: 5
            options: [
                { value: 9.5, label: i18n("Small") },
                { value: 10.5, label: i18n("Default") },
                { value: 12, label: i18n("Large") },
                { value: 13.5, label: i18n("Larger") }
            ]
            currentValue: page.fontSize
            onSelected: value => page.setFontSize(value)
        }
        ChoiceItem {
            title: i18n("Animations")
            icon: "preferences-desktop-effects"
            accent: 5
            options: [
                { value: 0, label: i18n("Off") },
                { value: 0.5, label: i18n("Faster") },
                { value: 1, label: i18n("Normal") },
                { value: 2, label: i18n("Slower") }
            ]
            currentValue: Number(animationFactor.value)
            onSelected: value => {
                animationFactor.value = value;
                DBus.call("session", "org.kde.KWin", "/KWin", "org.kde.KWin", "reconfigure", [], null);
            }
        }
        ListItem {
            title: i18n("Fonts")
            subtitle: i18n("Typefaces for the interface and for code")
            icon: "preferences-desktop-font"
            iconStyle: "plain"
            chevron: true
            onClicked: page.open("FontsPage.qml", {})
        }
    }

    Dialogs.FileDialog {
        id: pictureDialog
        title: i18n("Choose a picture")
        nameFilters: [i18n("Pictures (*.png *.jpg *.jpeg *.webp *.avif *.svg)")]
        currentFolder: Files.standardFolder("pictures")
        onAccepted: page.chooseImage(selectedFile)
    }
    component ColourSwatch: QQC2.AbstractButton {
        id: swatchButton
        property var swatch: ({})
        property string name
        property bool selected: false
        implicitWidth: 56
        implicitHeight: 56
        opacity: enabled ? 1 : 0.6
        Accessible.name: name
        QQC2.ToolTip.visible: hovered
        QQC2.ToolTip.text: name
        QQC2.ToolTip.delay: 400
        background: Item {
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.width: swatchButton.selected ? 3 : 0
                border.color: M3.primary
            }
            RoundedClip {
                anchors.fill: parent
                anchors.margins: swatchButton.selected ? 6 : 0
                radius: width / 2
                Behavior on anchors.margins { NumberAnimation { duration: M3.durationShort4 } }

                Rectangle {
                    width: parent.width
                    height: parent.height / 2
                    color: swatchButton.swatch.primary || "gray"
                }
                Rectangle {
                    y: parent.height / 2
                    width: parent.width / 2
                    height: parent.height / 2
                    color: swatchButton.swatch.secondaryContainer || "gray"
                }
                Rectangle {
                    x: parent.width / 2
                    y: parent.height / 2
                    width: parent.width / 2
                    height: parent.height / 2
                    color: swatchButton.swatch.tertiary || "gray"
                }
                MStateLayer {
                    anchors.fill: parent
                    radius: width / 2
                    hovered: swatchButton.hovered
                    pressed: swatchButton.pressed
                }
            }
            Rectangle {
                anchors.centerIn: parent
                width: 24
                height: 24
                radius: 12
                visible: swatchButton.selected
                color: M3.primaryContainer
                MIcon {
                    anchors.centerIn: parent
                    size: 16
                    source: "checkmark"
                    color: M3.primaryContainerContent
                }
            }
        }
        contentItem: Item {}
    }
}
