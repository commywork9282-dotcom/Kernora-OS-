/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Window
import Qt.labs.folderlistmodel
import org.kernora.m3
import org.kernora.ui
import org.kernora.system

AppWindow {
    id: app

    width: 1100
    height: 740
    minimumWidth: 420
    minimumHeight: 360
    color: viewing ? "#000000" : M3.surfaceContainer
    visible: true
    title: viewing ? decodeURIComponent(String(current).split("/").pop()) : i18n("Photos")

    property var pictures: []
    property int index: -1
    readonly property url current: index >= 0 && index < pictures.length ? pictures[index] : ""
    readonly property bool viewing: index >= 0
    property bool fullScreen: false

    property url galleryFolder: Files.standardFolder("pictures")

    function show(url: url): void {
        pictures = Files.siblings(url, "image/");
        index = Math.max(0, pictures.map(String).indexOf(String(url)));
        viewer.reset();
    }
    function closeViewer(): void {
        slideshow.running = false;
        index = -1;
        if (fullScreen) {
            toggleFullScreen();
        }
    }
    function next(step: int): void {
        if (pictures.length > 0) {
            index = (index + step + pictures.length) % pictures.length;
            viewer.reset();
        }
    }
    function toggleFullScreen(): void {
        fullScreen = !fullScreen;
        app.visibility = fullScreen ? Window.FullScreen : Window.Windowed;
    }

    function handleArguments(args: var): void {
        for (const argument of args || []) {
            const url = String(argument);
            if (url.startsWith("file:")) {
                if (Files.info(url).isDir) {
                    galleryFolder = url;
                    closeViewer();
                } else {
                    show(url);
                }
                return;
            }
        }
    }
    Component.onCompleted: handleArguments(startArguments)

    function trashCurrent(): void {
        const url = current;
        Files.trash([url], (ok, message) => {
            if (!ok) {
                app.showMessage(message, "", null);
                return;
            }
            const list = app.pictures.slice();
            list.splice(app.index, 1);
            app.pictures = list;
            if (list.length === 0) {
                app.closeViewer();
            } else {
                app.index = Math.min(app.index, list.length - 1);
            }
            app.showMessage(i18n("Moved to the trash"), "", null);
        });
    }

    Shortcut { sequences: ["Right", "Space", "PgDown"]; enabled: app.viewing; onActivated: app.next(1) }
    Shortcut { sequences: ["Left", "Backspace", "PgUp"]; enabled: app.viewing; onActivated: app.next(-1) }
    Shortcut { sequence: "Escape"; enabled: app.viewing; onActivated: app.fullScreen ? app.toggleFullScreen() : app.closeViewer() }
    Shortcut { sequences: ["F11", "F"]; enabled: app.viewing; onActivated: app.toggleFullScreen() }
    Shortcut { sequences: [StandardKey.ZoomIn, "+", "="]; enabled: app.viewing; onActivated: viewer.zoomBy(1.25) }
    Shortcut { sequences: [StandardKey.ZoomOut, "-"]; enabled: app.viewing; onActivated: viewer.zoomBy(0.8) }
    Shortcut { sequences: ["0", "Ctrl+0"]; enabled: app.viewing; onActivated: viewer.reset() }
    Shortcut { sequence: "R"; enabled: app.viewing; onActivated: viewer.rotation += 90 }
    Shortcut { sequence: "Shift+R"; enabled: app.viewing; onActivated: viewer.rotation -= 90 }
    Shortcut { sequences: [StandardKey.Delete]; enabled: app.viewing; onActivated: app.trashCurrent() }
    Shortcut { sequence: "I"; enabled: app.viewing; onActivated: infoPanel.shown = !infoPanel.shown }

    FolderListModel {
        id: gallery
        folder: app.galleryFolder
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.bmp", "*.svg", "*.avif", "*.tif", "*.tiff", "*.jxl",
                      "*.PNG", "*.JPG", "*.JPEG", "*.WEBP"]
        showDirs: true
        showDirsFirst: true
        sortField: FolderListModel.Time
        sortReversed: false
    }

    ColumnLayout {
        anchors.fill: parent
        visible: !app.viewing
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 12
            Layout.leftMargin: 24
            spacing: 8

            IconButton {
                visible: String(app.galleryFolder) !== String(Files.standardFolder("pictures"))
                iconName: "go-previous"
                text: i18n("Back")
                onClicked: app.galleryFolder = String(app.galleryFolder).replace(/\/[^/]*\/?$/, "")
            }
            MText {
                Layout.fillWidth: true
                role: "headlineSmall"
                text: String(app.galleryFolder) === String(Files.standardFolder("pictures"))
                    ? i18n("Pictures") : decodeURIComponent(String(app.galleryFolder).split("/").pop())
            }
            IconButton {
                iconName: "folder-open"
                text: i18n("Open in Files")
                onClicked: Process.launchApplication("org.kernora.files.desktop", [app.galleryFolder])
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            Layout.bottomMargin: 12
            radius: M3.classic ? M3.cornerCard : 28
            color: M3.surface
            clip: true

            GridView {
                id: grid
                anchors.fill: parent
                anchors.margins: 12
                model: gallery
                cellWidth: width / Math.max(2, Math.floor(width / 200))
                cellHeight: cellWidth
                boundsBehavior: Flickable.StopAtBounds
                QQC2.ScrollBar.vertical: QQC2.ScrollBar {}

                delegate: Item {
                    id: tile
                    required property url fileUrl
                    required property string fileName
                    required property bool fileIsDir
                    width: grid.cellWidth
                    height: grid.cellHeight

                    RoundedClip {
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: M3.classic ? M3.cornerImage : 16 + 12 * hoverMorph.value - 6 * pressMorph.value
                        MMorph { id: hoverMorph; active: tileMouse.containsMouse }
                        MMorph { id: pressMorph; active: tileMouse.pressed }

                        Rectangle { anchors.fill: parent; color: tile.fileIsDir ? M3.primaryContainer : M3.surfaceContainerHigh }
                        Image {
                            anchors.fill: parent
                            visible: !tile.fileIsDir
                            source: tile.fileIsDir ? "" : tile.fileUrl
                            sourceSize: Qt.size(400, 400)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                        ColumnLayout {
                            anchors.centerIn: parent
                            visible: tile.fileIsDir
                            width: parent.width - 24
                            MIcon { Layout.alignment: Qt.AlignHCenter; size: 40; source: "folder-pictures"; color: M3.primaryContainerContent }
                            MText { Layout.fillWidth: true; role: "labelLarge"; text: tile.fileName; horizontalAlignment: Text.AlignHCenter; color: M3.primaryContainerContent }
                        }
                        MStateLayer {
                            anchors.fill: parent
                            hovered: tileMouse.containsMouse
                            pressed: tileMouse.pressed
                            pressPoint: Qt.point(tileMouse.mouseX, tileMouse.mouseY)
                        }
                    }
                    MouseArea {
                        id: tileMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: tile.fileIsDir ? app.galleryFolder = tile.fileUrl : app.show(tile.fileUrl)
                    }
                }
            }

            EmptyState {
                anchors.centerIn: parent
                width: parent.width - 48
                visible: gallery.status === FolderListModel.Ready && gallery.count === 0
                icon: "kernora-photos"
                title: i18n("No pictures yet")
                text: i18n("Pictures you save to the Pictures folder, and screenshots, show up here.")
            }
        }
    }

    Item {
        id: stage
        anchors.fill: parent
        visible: app.viewing

        Flickable {
            id: flick
            anchors.fill: parent
            contentWidth: Math.max(width, viewer.paintedWidth * viewer.zoom)
            contentHeight: Math.max(height, viewer.paintedHeight * viewer.zoom)
            interactive: viewer.zoom > 1.01
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Image {
                id: viewer

                property real zoom: 1

                function reset(): void {
                    zoom = 1;
                    rotation = 0;
                }
                function zoomBy(factor: real): void {
                    zoom = Math.max(1, Math.min(12, zoom * factor));
                }

                width: flick.width
                height: flick.height
                x: (flick.contentWidth - width) / 2
                y: (flick.contentHeight - height) / 2
                scale: zoom
                source: app.current
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                autoTransform: true
                smooth: true
                mipmap: true
                sourceSize: Qt.size(Math.max(width, 2400), Math.max(height, 2400))
                Behavior on rotation { NumberAnimation { duration: M3.durationMedium2; easing.type: Easing.Bezier; easing.bezierCurve: M3.easingStandard } }
                Behavior on zoom { NumberAnimation { duration: M3.durationShort4 } }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                onDoubleClicked: viewer.zoom > 1.01 ? viewer.reset() : viewer.zoomBy(2.5)
                onClicked: chrome.shown = !chrome.shown
                onWheel: wheel => {
                    if (wheel.modifiers & Qt.ControlModifier || viewer.zoom > 1.01) {
                        viewer.zoomBy(wheel.angleDelta.y > 0 ? 1.15 : 0.87);
                    } else {
                        app.next(wheel.angleDelta.y > 0 ? -1 : 1);
                    }
                }
            }
            PinchHandler {
                target: null
                onScaleChanged: delta => viewer.zoomBy(delta)
            }
        }

        BusyIndicatorOverlay {
            anchors.centerIn: parent
            visible: viewer.status === Image.Loading
        }

        Item {
            id: chrome
            property bool shown: true
            anchors.fill: parent
            opacity: shown ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: M3.durationMedium1 } }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                height: 96
                gradient: Gradient {
                    GradientStop { position: 0; color: "#b0000000" }
                    GradientStop { position: 1; color: "#00000000" }
                }
            }
            RowLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: 4

                ViewerButton { icon.name: "go-previous"; text: i18n("Back to the gallery"); onClicked: app.closeViewer() }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    spacing: 0
                    Text {
                        Layout.fillWidth: true
                        text: app.title
                        color: "white"
                        font: M3.titleMedium
                        elide: Text.ElideMiddle
                    }
                    Text {
                        text: i18n("%1 of %2", app.index + 1, app.pictures.length)
                        color: "#ccffffff"
                        font: M3.bodySmall
                    }
                }
                ViewerButton { visible: M3.classic; icon.name: "object-rotate-left"; text: i18n("Rotate left"); onClicked: viewer.rotation -= 90 }
                ViewerButton { visible: M3.classic; icon.name: "transform-rotate-right"; text: i18n("Rotate right"); onClicked: viewer.rotation += 90 }
                ViewerButton { visible: M3.classic; icon.name: "view-presentation"; text: i18n("Slideshow"); checked: slideshow.running; onClicked: slideshow.running = !slideshow.running }
                ViewerButton { visible: M3.classic; icon.name: "help-about"; text: i18n("Details"); checked: infoPanel.shown; onClicked: infoPanel.shown = !infoPanel.shown }
                ViewerButton { visible: M3.classic; icon.name: app.fullScreen ? "view-restore" : "view-fullscreen"; text: i18n("Full screen"); onClicked: app.toggleFullScreen() }
                ViewerButton {
                    id: moreButton
                    visible: M3.classic
                    icon.name: "overflow-menu"
                    text: i18n("More")
                    onClicked: moreMenu.popup(moreButton, 0, moreButton.height)
                }
            }

            FloatingToolbar {
                id: toolbar
                visible: !M3.classic && opacity > 0
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: infoPanel.width > 0 ? -(infoPanel.width + 12) / 2 : 0
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 24
                vibrant: true
                shown: chrome.shown

                ToolbarButton { iconName: "object-rotate-left"; text: i18n("Rotate left"); onClicked: viewer.rotation -= 90 }
                ToolbarButton { iconName: "transform-rotate-right"; text: i18n("Rotate right"); onClicked: viewer.rotation += 90 }
                ToolbarButton { iconName: "view-presentation"; text: i18n("Slideshow"); checked: slideshow.running; onClicked: slideshow.running = !slideshow.running }
                ToolbarButton { iconName: "help-about"; text: i18n("Details"); checked: infoPanel.shown; onClicked: infoPanel.shown = !infoPanel.shown }
                ToolbarButton { iconName: app.fullScreen ? "view-restore" : "view-fullscreen"; text: i18n("Full screen"); onClicked: app.toggleFullScreen() }
                ToolbarButton {
                    id: toolbarMore
                    iconName: "overflow-menu"
                    text: i18n("More")
                    onClicked: {
                        moreMenu.popup(toolbarMore, 0, 0);
                        moreMenu.y = Qt.binding(() => -moreMenu.height - 16);
                    }
                }
            }

            ViewerButton {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                visible: app.pictures.length > 1
                icon.name: "go-previous"
                text: i18n("Previous")
                onClicked: app.next(-1)
            }
            ViewerButton {
                anchors.right: parent.right
                anchors.rightMargin: infoPanel.shown ? infoPanel.width + 16 : 16
                anchors.verticalCenter: parent.verticalCenter
                visible: app.pictures.length > 1
                icon.name: "go-next"
                text: i18n("Next")
                onClicked: app.next(1)
            }
        }

        Rectangle {
            id: infoPanel
            property bool shown: false
            readonly property var info: app.viewing ? Files.info(app.current) : ({})
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 12
            width: shown ? 300 : 0
            visible: width > 0
            radius: M3.classic ? M3.cornerCard : 28
            color: M3.surfaceContainerHigh
            clip: true
            Behavior on width { NumberAnimation { duration: M3.durationMedium2; easing.type: Easing.Bezier; easing.bezierCurve: M3.easingEmphasizedDecelerate } }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 14
                MText { role: "titleLarge"; text: i18n("Details") }
                MText { role: "labelLarge"; color: M3.surfaceVariantContent; text: i18n("Name") }
                MText { Layout.fillWidth: true; role: "bodyMedium"; text: infoPanel.info.name || ""; wrapMode: Text.WrapAnywhere }
                MText { role: "labelLarge"; color: M3.surfaceVariantContent; text: i18n("Size") }
                MText { role: "bodyMedium"; text: i18n("%1 × %2 pixels · %3", viewer.implicitWidth, viewer.implicitHeight, infoPanel.info.sizeText || "") }
                MText { role: "labelLarge"; color: M3.surfaceVariantContent; text: i18n("Modified") }
                MText { role: "bodyMedium"; text: infoPanel.info.modified ? infoPanel.info.modified.toLocaleString(Qt.locale(), Locale.ShortFormat) : "" }
                MText { role: "labelLarge"; color: M3.surfaceVariantContent; text: i18n("Folder") }
                MText { Layout.fillWidth: true; role: "bodyMedium"; text: decodeURIComponent(String(infoPanel.info.folder || "").replace(/^file:\/\//, "")); wrapMode: Text.WrapAnywhere }
                Item { Layout.fillHeight: true }
            }
        }
    }

    Timer {
        id: slideshow
        interval: 4000
        repeat: true
        onTriggered: app.next(1)
    }

    QQC2.Menu {
        id: moreMenu
        QQC2.MenuItem {
            text: i18n("Set as wallpaper")
            icon.name: "preferences-desktop-wallpaper"
            onTriggered: {
                Files.setWallpaper(app.current);
                app.showMessage(i18n("Wallpaper changed"), "", null);
            }
        }
        QQC2.MenuItem { text: i18n("Show in Files"); icon.name: "system-file-manager"; onTriggered: Process.launchApplication("org.kernora.files.desktop", [app.current]) }
        QQC2.MenuItem {
            text: i18n("Open with another app")
            icon.name: "document-open"
            onTriggered: Process.openUrl(app.current)
        }
        QQC2.MenuSeparator {}
        QQC2.MenuItem { text: i18n("Move to trash"); icon.name: "user-trash"; onTriggered: app.trashCurrent() }
    }

    component ToolbarButton: IconButton {
        implicitWidth: 48
        implicitHeight: 48
        ink: toolbar.ink
        checkedFill: toolbar.checkedFill
        checkedInk: toolbar.checkedInk
    }
    component ViewerButton: QQC2.RoundButton {
        display: QQC2.AbstractButton.IconOnly
        icon.color: "white"
        flat: !checked
        implicitWidth: 48
        implicitHeight: 48
        QQC2.ToolTip.text: text
        QQC2.ToolTip.visible: hovered
        QQC2.ToolTip.delay: 600
        background: Rectangle {
            radius: width / 2
            color: parent.checked ? "#66ffffff" : parent.hovered ? "#33ffffff" : "#26000000"
        }
    }
    component BusyIndicatorOverlay: MLoadingIndicator {
        width: 64
        height: 64
        contained: true
        running: visible
    }
}
