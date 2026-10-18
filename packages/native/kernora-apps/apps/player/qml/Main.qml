/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Dialogs as Dialogs
import QtQuick.Window
import QtMultimedia
import Qt.labs.folderlistmodel
import org.kernora.m3
import org.kernora.ui
import org.kernora.system

AppWindow {
    id: app

    width: 1040
    height: 700
    minimumWidth: 420
    minimumHeight: 380
    visible: true
    color: video ? "#000000" : M3.surfaceContainer
    title: loaded ? mediaTitle : i18n("Media Player")

    property var queue: []
    property int index: -1
    readonly property url current: index >= 0 && index < queue.length ? queue[index] : ""
    readonly property bool loaded: index >= 0
    readonly property bool video: loaded && player.hasVideo
    readonly property bool playing: player.playbackState === MediaPlayer.PlayingState
    property bool fullScreen: false
    property int repeatMode: 0

    readonly property string mediaTitle: {
        const title = player.metaData.value(MediaMetaData.Title);
        return title ? String(title) : decodeURIComponent(String(current).split("/").pop()).replace(/\.[^.]+$/, "");
    }
    readonly property string mediaArtist: {
        const artist = player.metaData.value(MediaMetaData.ContributingArtist) || player.metaData.value(MediaMetaData.AlbumArtist);
        const album = player.metaData.value(MediaMetaData.AlbumTitle);
        return [artist, album].filter(v => v).join(" · ");
    }

    function play(url: url): void {
        const kind = Files.mimeType(url).split("/")[0];
        queue = Files.siblings(url, kind === "audio" ? "audio/" : "video/");
        index = Math.max(0, queue.map(String).indexOf(String(url)));
        player.source = current;
        player.play();
    }
    function playAt(row: int): void {
        index = row;
        player.source = current;
        player.play();
    }
    function next(step: int): void {
        if (queue.length === 0) {
            return;
        }
        if (step < 0 && player.position > 3000) {
            player.position = 0;
            return;
        }
        playAt((index + step + queue.length) % queue.length);
    }
    function toggleFullScreen(): void {
        fullScreen = !fullScreen;
        app.visibility = fullScreen ? Window.FullScreen : Window.Windowed;
    }
    function time(ms: real): string {
        const total = Math.max(0, Math.floor(ms / 1000));
        const h = Math.floor(total / 3600);
        const m = Math.floor(total / 60) % 60;
        const s = String(total % 60).padStart(2, "0");
        return h > 0 ? h + ":" + String(m).padStart(2, "0") + ":" + s : m + ":" + s;
    }

    function handleArguments(args: var): void {
        for (const argument of args || []) {
            const url = String(argument);
            if (url.startsWith("file:") && !Files.info(url).isDir) {
                play(url);
                return;
            }
        }
    }
    Component.onCompleted: handleArguments(startArguments)

    MediaPlayer {
        id: player
        audioOutput: AudioOutput {
            id: audio
            volume: 1
        }
        videoOutput: videoOutput
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.EndOfMedia) {
                if (app.repeatMode === 2) {
                    player.position = 0;
                    player.play();
                } else if (app.index < app.queue.length - 1 || app.repeatMode === 1) {
                    app.next(1);
                }
            }
        }
        onErrorOccurred: (error, message) => app.showMessage(message || i18n("This file cannot be played."), "", null)
    }

    MprisPlayer {
        id: mpris
        name: "kernora_player"
        identity: i18n("Media Player")
        desktopEntry: "org.kernora.player"
        loaded: app.loaded
        playing: app.playing
        canGoNext: app.queue.length > 1
        canGoPrevious: app.loaded
        canSeek: player.seekable
        url: app.current
        title: app.mediaTitle
        artist: {
            const artist = player.metaData.value(MediaMetaData.ContributingArtist) || player.metaData.value(MediaMetaData.AlbumArtist);
            return artist ? String(artist) : "";
        }
        album: {
            const album = player.metaData.value(MediaMetaData.AlbumTitle);
            return album ? String(album) : "";
        }
        coverImage: player.metaData.value(MediaMetaData.CoverArtImage) || player.metaData.value(MediaMetaData.ThumbnailImage) || null
        length: player.duration
        position: player.position

        onPlayRequested: if (app.loaded) player.play()
        onPauseRequested: player.pause()
        onStopRequested: player.stop()
        onNextRequested: app.next(1)
        onPreviousRequested: app.next(-1)
        onSeekRequested: offset => {
            player.position = Math.max(0, Math.min(player.duration, player.position + offset));
            mpris.seeked(player.position);
        }
        onPositionRequested: position => {
            player.position = position;
            mpris.seeked(position);
        }
        onRaiseRequested: {
            app.show();
            app.raise();
            app.requestActivate();
        }
        onQuitRequested: Qt.quit()
    }

    Shortcut { sequences: ["Space", "K", "Media Play"]; enabled: app.loaded; onActivated: app.playing ? player.pause() : player.play() }
    Shortcut { sequences: ["Right", "L"]; enabled: app.loaded; onActivated: player.position = Math.min(player.duration, player.position + 10000) }
    Shortcut { sequences: ["Left", "J"]; enabled: app.loaded; onActivated: player.position = Math.max(0, player.position - 10000) }
    Shortcut { sequences: ["Up"]; onActivated: audio.volume = Math.min(1, audio.volume + 0.05) }
    Shortcut { sequences: ["Down"]; onActivated: audio.volume = Math.max(0, audio.volume - 0.05) }
    Shortcut { sequences: ["M"]; onActivated: audio.muted = !audio.muted }
    Shortcut { sequences: ["F11", "F"]; enabled: app.video; onActivated: app.toggleFullScreen() }
    Shortcut { sequence: "Escape"; enabled: app.fullScreen; onActivated: app.toggleFullScreen() }
    Shortcut { sequences: ["N", "Media Next"]; enabled: app.loaded; onActivated: app.next(1) }
    Shortcut { sequences: ["P", "Media Previous"]; enabled: app.loaded; onActivated: app.next(-1) }
    Shortcut { sequences: [StandardKey.Open]; onActivated: openDialog.open() }

    FolderListModel {
        id: music
        folder: Files.standardFolder("music")
        nameFilters: ["*.mp3", "*.flac", "*.ogg", "*.oga", "*.opus", "*.wav", "*.m4a", "*.aac"]
        showDirs: false
    }
    FolderListModel {
        id: videos
        folder: Files.standardFolder("videos")
        nameFilters: ["*.mp4", "*.mkv", "*.webm", "*.avi", "*.mov", "*.m4v", "*.ogv", "*.mpg"]
        showDirs: false
    }

    ColumnLayout {
        anchors.fill: parent
        visible: !app.loaded
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 12
            Layout.leftMargin: 24
            MText {
                Layout.fillWidth: true
                role: "headlineSmall"
                text: i18n("Media Player")
            }
            QQC2.Button {
                text: i18n("Open a file")
                icon.name: "document-open"
                highlighted: true
                onClicked: openDialog.open()
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

            Flickable {
                anchors.fill: parent
                contentHeight: library.implicitHeight + 48
                boundsBehavior: Flickable.StopAtBounds
                QQC2.ScrollBar.vertical: QQC2.ScrollBar {}

                Column {
                    id: library
                    x: 24
                    y: 24
                    width: parent.width - 48
                    spacing: 28

                    Group {
                        title: i18n("Music")
                        visible: music.count > 0
                        Repeater {
                            model: music
                            delegate: ListItem {
                                required property url fileUrl
                                required property string fileBaseName
                                title: fileBaseName
                                icon: "audio-x-generic"
                                accent: 1
                                onClicked: app.play(fileUrl)
                            }
                        }
                    }
                    Group {
                        title: i18n("Videos")
                        visible: videos.count > 0
                        Repeater {
                            model: videos
                            delegate: ListItem {
                                required property url fileUrl
                                required property string fileBaseName
                                title: fileBaseName
                                icon: "video-x-generic"
                                accent: 5
                                onClicked: app.play(fileUrl)
                            }
                        }
                    }
                }
            }

            EmptyState {
                anchors.centerIn: parent
                width: parent.width - 48
                visible: music.count === 0 && videos.count === 0
                icon: "applications-multimedia"
                title: i18n("Nothing to play yet")
                text: i18n("Music from your Music folder and videos from your Videos folder appear here. You can also open any file.")
                actionText: i18n("Open a file")
                onActionTriggered: openDialog.open()
            }
        }
    }

    VideoOutput {
        id: videoOutput
        anchors.fill: parent
        visible: app.video

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: controls.shown ? Qt.ArrowCursor : Qt.BlankCursor
            onPositionChanged: controls.wake()
            onClicked: {
                controls.wake();
                app.playing ? player.pause() : player.play();
            }
            onDoubleClicked: app.toggleFullScreen()
        }
    }

    Item {
        id: controls
        property bool shown: true
        function wake(): void {
            shown = true;
            idle.restart();
        }
        Timer {
            id: idle
            interval: 3000
            running: app.video && app.playing
            onTriggered: controls.shown = !app.video || !app.playing
        }
        anchors.fill: parent
        visible: app.video && opacity > 0
        opacity: shown || !app.playing ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: M3.durationMedium2 } }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 180
            gradient: Gradient {
                GradientStop { position: 0; color: "#00000000" }
                GradientStop { position: 1; color: "#c0000000" }
            }
        }
        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 24
            text: app.mediaTitle
            color: "white"
            font: M3.titleLarge
            style: Text.Raised
            styleColor: "#80000000"
        }
        Transport {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 20
            light: true
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        visible: app.loaded && !app.video
        spacing: 12

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: M3.classic ? M3.cornerCard : 28
            color: M3.surface

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 32
                spacing: 20

                IconButton {
                    iconName: "go-previous"
                    text: i18n("Library")
                    onClicked: {
                        player.stop();
                        app.index = -1;
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Rectangle {
                        id: art
                        readonly property bool hasCover: cover.status === Image.Ready
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height, 320)
                        height: width
                        readonly property real playing: M3.classic ? 0 : playMorph.value
                        radius: M3.classic ? M3.cornerImage : width * (0.1 + (0.32 - 0.14 * coverMorph.value - 0.1) * playing)
                        rotation: 8 * playing * (1 - coverMorph.value)
                        color: M3.accent(1).container
                        MMorph {
                            id: playMorph
                            active: app.playing
                            dampingRatio: M3.springExpressiveDefaultDamping
                            response: M3.springExpressiveDefaultResponse
                        }
                        MMorph {
                            id: coverMorph
                            active: art.hasCover
                            dampingRatio: M3.springExpressiveDefaultDamping
                            response: M3.springExpressiveDefaultResponse
                        }
                        MIcon {
                            anchors.centerIn: parent
                            rotation: -art.rotation
                            size: parent.width * 0.4
                            source: "audio-x-generic"
                            color: M3.accent(1).content
                            visible: !art.hasCover
                        }
                        RoundedClip {
                            anchors.fill: parent
                            radius: art.radius
                            visible: art.hasCover
                            Image {
                                id: cover
                                anchors.fill: parent
                                source: mpris.artUrl
                                fillMode: Image.PreserveAspectCrop
                                sourceSize.width: 640
                                asynchronous: true
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    MText {
                        Layout.fillWidth: true
                        role: "headlineSmall"
                        text: app.mediaTitle
                        horizontalAlignment: Text.AlignHCenter
                    }
                    MText {
                        Layout.fillWidth: true
                        role: "bodyLarge"
                        text: app.mediaArtist
                        visible: text.length > 0
                        color: M3.surfaceVariantContent
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                Transport {
                    Layout.fillWidth: true
                    light: false
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: 320
            Layout.fillHeight: true
            visible: app.width > 780 && app.queue.length > 1
            radius: M3.classic ? M3.cornerCard : 28
            color: M3.surfaceContainerLow

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 8
                MText {
                    Layout.leftMargin: 8
                    role: "titleMedium"
                    text: i18n("Up next")
                }
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 2
                    model: app.queue
                    boundsBehavior: Flickable.StopAtBounds
                    QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
                    delegate: NavigationItem {
                        required property url modelData
                        required property int index
                        width: ListView.view.width
                        height: 52
                        title: decodeURIComponent(String(modelData).split("/").pop()).replace(/\.[^.]+$/, "")
                        current: index === app.index
                        leading: Component {
                            MIcon {
                                size: 22
                                source: "audio-x-generic"
                                color: M3.surfaceVariantContent
                            }
                        }
                        onClicked: app.playAt(index)
                    }
                }
            }
        }
    }

    component Transport: ColumnLayout {
        id: transport
        property bool light: false
        readonly property color ink: light ? "white" : M3.surfaceContent
        readonly property color soft: light ? "#ccffffff" : M3.surfaceVariantContent
        spacing: 6

        MSlider {
            Layout.fillWidth: true
            trackHeight: 12
            from: 0
            to: Math.max(1, player.duration)
            value: player.position
            stepSize: 1000
            enabled: player.seekable
            formatValue: v => app.time(v)
            onMoved: value => player.position = value
        }
        RowLayout {
            Layout.fillWidth: true
            MText { role: "labelMedium"; color: transport.soft; text: app.time(player.position) }
            Item { Layout.fillWidth: true }
            MText { role: "labelMedium"; color: transport.soft; text: app.time(player.duration) }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            TransportButton {
                icon.name: app.repeatMode === 2 ? "media-playlist-repeat-song" : "media-playlist-repeat"
                text: app.repeatMode === 0 ? i18n("Repeat: off") : app.repeatMode === 1 ? i18n("Repeat: all") : i18n("Repeat: this one")
                checked: app.repeatMode > 0
                ink: transport.ink
                onClicked: app.repeatMode = (app.repeatMode + 1) % 3
            }
            Item { Layout.fillWidth: true }
            TransportButton { icon.name: "media-skip-backward"; text: i18n("Previous"); ink: transport.ink; onClicked: app.next(-1) }
            TransportButton {
                size: 72
                iconSize: 34
                tonal: true
                icon.name: app.playing ? "media-playback-pause" : "media-playback-start"
                text: app.playing ? i18n("Pause") : i18n("Play")
                onClicked: app.playing ? player.pause() : player.play()
            }
            TransportButton { icon.name: "media-skip-forward"; text: i18n("Next"); ink: transport.ink; onClicked: app.next(1) }
            Item { Layout.fillWidth: true }
            TransportButton {
                id: speedButton
                icon.name: "kernora-speed"
                text: i18n("Speed: %1×", player.playbackRate)
                ink: transport.ink
                checked: player.playbackRate !== 1
                onClicked: speedMenu.popup(speedButton, 0, -speedMenu.implicitHeight)
            }
            TransportButton {
                icon.name: audio.muted || audio.volume === 0 ? "audio-volume-muted" : "audio-volume-high"
                text: audio.muted ? i18n("Unmute") : i18n("Mute")
                ink: transport.ink
                onClicked: audio.muted = !audio.muted
            }
            TransportButton {
                visible: app.video
                icon.name: app.fullScreen ? "view-restore" : "view-fullscreen"
                text: i18n("Full screen")
                ink: transport.ink
                onClicked: app.toggleFullScreen()
            }
        }
    }

    component TransportButton: QQC2.AbstractButton {
        id: button
        property color ink: M3.surfaceContent
        property int size: 48
        property int iconSize: 24
        property bool tonal: false
        implicitWidth: size
        implicitHeight: size
        focusPolicy: Qt.TabFocus
        QQC2.ToolTip.text: text
        QQC2.ToolTip.visible: hovered && !tonal
        QQC2.ToolTip.delay: 600
        Accessible.name: text
        contentItem: Item {}
        MMorph { id: shapeMorph; active: button.tonal && !M3.classic && app.playing }
        MMorph { id: pressMorph; active: button.pressed && !M3.classic }
        background: Rectangle {
            readonly property real rest: button.height / 2 + (24 - button.height / 2) * shapeMorph.value
            radius: Math.max(0, rest + (button.height * 0.22 - rest) * pressMorph.value)
            color: button.tonal ? M3.primaryContainer : button.checked ? M3.withAlpha(M3.primary, 0.14) : "transparent"
            MStateLayer {
                radius: parent.radius
                color: button.tonal ? M3.primaryContainerContent : button.ink
                hovered: button.hovered
                pressed: button.pressed
                focused: button.visualFocus
            }
            MIcon {
                anchors.centerIn: parent
                size: button.iconSize
                source: button.icon.name
                color: button.tonal ? M3.primaryContainerContent : button.checked ? M3.primary : button.ink
            }
        }
    }

    QQC2.Menu {
        id: speedMenu
        Instantiator {
            model: [0.5, 0.75, 1, 1.25, 1.5, 2]
            delegate: QQC2.MenuItem {
                required property real modelData
                text: modelData === 1 ? i18n("Normal") : i18n("%1×", modelData)
                checkable: true
                checked: player.playbackRate === modelData
                onTriggered: player.playbackRate = modelData
            }
            onObjectAdded: (index, object) => speedMenu.insertItem(index, object)
            onObjectRemoved: (index, object) => speedMenu.removeItem(object)
        }
    }

    Dialogs.FileDialog {
        id: openDialog
        title: i18n("Open a video or music file")
        currentFolder: Files.standardFolder("videos")
        nameFilters: [i18n("Media files (*.mp4 *.mkv *.webm *.avi *.mov *.m4v *.ogv *.mpg *.mp3 *.flac *.ogg *.oga *.opus *.wav *.m4a *.aac)"), i18n("All files (*)")]
        onAccepted: app.play(selectedFile)
    }
}
