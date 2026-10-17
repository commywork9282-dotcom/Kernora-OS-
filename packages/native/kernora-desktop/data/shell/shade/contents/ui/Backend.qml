/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kcmutils as KCMUtils
import org.kde.plasma.plasma5support as P5Support

Item {
    id: root

    visible: false

    Loader { id: networkLoader; source: "sources/NetworkSource.qml" }
    Loader { id: bluetoothLoader; source: "sources/BluetoothSource.qml" }
    Loader { id: audioLoader; source: "sources/AudioSource.qml" }
    Loader { id: displayLoader; source: "sources/DisplaySource.qml" }
    Loader { id: batteryLoader; source: "sources/BatterySource.qml" }
    Loader { id: awakeLoader; source: "sources/AwakeSource.qml" }
    Loader { id: sessionLoader; source: "sources/SessionSource.qml" }
    Loader { id: notificationLoader; source: "sources/NotificationSource.qml" }
    Loader { id: mediaLoader; source: "sources/MediaSource.qml" }
    Loader { id: deviceLoader; source: "sources/DeviceSource.qml" }
    Loader { id: themeLoader; source: "sources/ThemeSource.qml" }

    readonly property var network: networkLoader.item
    readonly property var bluetooth: bluetoothLoader.item
    readonly property var audio: audioLoader.item
    readonly property var display: displayLoader.item
    readonly property var battery: batteryLoader.item
    readonly property var awake: awakeLoader.item
    readonly property var session: sessionLoader.item
    readonly property var notifications: notificationLoader.item
    readonly property var media: mediaLoader.item
    readonly property var theme: themeLoader.item

    property date now: new Date()
    Timer {
        interval: 60000 - (Date.now() % 60000) + 50
        running: true
        repeat: true
        onTriggered: {
            root.now = new Date();
            interval = 60000 - (Date.now() % 60000) + 50;
        }
    }
    readonly property string timeFormat: Qt.locale().timeFormat(Locale.ShortFormat)
        .replace(/[.:]?s+/g, "").replace(/\s+t$/, "").trim()
    readonly property string timeText: Qt.formatTime(now, timeFormat)
    readonly property string dateText: now.toLocaleDateString(Qt.locale(), "dddd, d MMMM")

    readonly property bool hasBattery: battery ? battery.hasBattery : false
    readonly property int batteryPercent: battery ? battery.batteryPercent : 0
    readonly property bool charging: battery ? battery.charging : false
    readonly property string batteryIcon: battery ? battery.batteryIcon : "battery-missing"

    readonly property bool canLock: session ? session.canLock : false
    readonly property bool canSuspend: session ? session.canSuspend : false
    readonly property bool canLogout: session ? session.canLogout : false
    readonly property bool canReboot: session ? session.canReboot : false
    readonly property bool canShutdown: session ? session.canShutdown : false
    function lock(): void { session?.lock(); }
    function suspend(): void { session?.suspend(); }
    function logout(): void { session?.logout(); }
    function reboot(): void { session?.reboot(); }
    function shutdown(): void { session?.shutdown(); }

    readonly property bool brightnessAvailable: display ? display.brightnessAvailable : false
    readonly property real brightness: display ? display.brightness : 0
    readonly property real brightnessMax: display ? display.brightnessMax : 100
    function setBrightness(value: real): void { display?.setBrightness(value); }

    readonly property bool soundAvailable: audio ? audio.soundAvailable : false
    readonly property bool soundMuted: audio ? audio.soundMuted : true
    readonly property real volume: audio ? audio.volume : 0
    readonly property real volumeMax: audio ? audio.volumeMax : 65536
    readonly property int volumePercent: audio ? audio.percent : 0
    readonly property string volumeIcon: audio ? audio.volumeIcon : "audio-volume-muted"
    readonly property string outputName: audio ? audio.outputName : ""
    function setVolume(value: real): void { audio?.setVolume(value); }
    function toggleMute(): void { audio?.toggleMute(); }

    readonly property string networkIcon: network ? network.statusIcon : "network-offline"
    readonly property bool wifiAvailable: network ? network.wifiAvailable : false
    readonly property bool wifiOn: network ? network.wifiOn : false
    readonly property string wifiSubtitle: network ? network.wifiSubtitle : i18n("Unavailable")
    function toggleWifi(): void { network?.toggleWifi(); }

    readonly property bool internetAvailable: network ? network.internetAvailable : false
    readonly property bool internetOn: network ? network.internetOn : false
    readonly property string internetIcon: network ? network.internetIcon : "network-offline"
    readonly property string internetSubtitle: network ? network.internetSubtitle : i18n("Unavailable")
    readonly property bool internetToggles: wifiAvailable && !airplaneOn
    function toggleInternet(): void { network?.toggleInternet(); }

    readonly property bool airplaneAvailable: network ? network.airplaneAvailable : false
    readonly property bool airplaneOn: network ? network.airplaneOn : false
    function toggleAirplane(): void { network?.toggleAirplane(); }

    readonly property bool btAvailable: bluetooth ? bluetooth.available : false
    readonly property bool btOn: bluetooth ? bluetooth.on : false
    readonly property string btSubtitle: bluetooth ? bluetooth.subtitle : i18n("Unavailable")
    function toggleBluetooth(): void { bluetooth?.toggle(); }

    readonly property bool micAvailable: audio ? audio.micAvailable : false
    readonly property bool micMuted: audio ? audio.micMuted : true
    function toggleMic(): void { audio?.toggleMic(); }

    readonly property bool dndAvailable: notifications ? notifications.available : false
    readonly property bool dndOn: notifications ? notifications.on : false
    function toggleDnd(): void { notifications?.toggle(); }

    readonly property bool nightAvailable: display ? display.nightAvailable : false
    readonly property bool nightOn: display ? display.nightOn : false
    readonly property string nightSubtitle: display ? display.nightSubtitle : i18n("Unavailable")
    readonly property bool nightNeedsSetup: display ? display.nightNeedsSetup : false
    function toggleNight(): void {
        if (display && display.nightNeedsSetup) {
            openSettings("kcm_nightlight");
            return;
        }
        display?.toggleNight();
    }

    readonly property bool awakeAvailable: awake !== null
    readonly property bool awakeOn: awake ? awake.on : false
    function toggleAwake(): void { awake?.toggle(); }

    readonly property bool themeAvailable: theme !== null
    readonly property bool darkOn: theme ? theme.dark : true
    readonly property bool themeBusy: theme ? theme.busy : false
    function toggleDark(): void { theme?.toggle(); }

    function takeScreenshot(): void {
        screenshotTimer.restart();
    }
    Timer {
        id: screenshotTimer
        interval: 500
        onTriggered: executable.connectSource("kernora-screenshot")
    }

    readonly property bool mediaActive: media ? media.active : false
    readonly property bool mediaPlaying: media ? media.playing : false
    readonly property string mediaTrack: media ? media.track : ""
    readonly property string mediaArtist: media ? media.artist : ""
    readonly property string mediaArtUrl: media ? media.artUrl : ""
    readonly property string mediaIdentity: media ? media.identity : ""
    readonly property string mediaIconName: media ? media.iconName : ""
    readonly property bool mediaCanPlayPause: media ? media.canPlayPause : false
    readonly property bool mediaCanNext: media ? media.canGoNext : false
    readonly property bool mediaCanPrevious: media ? media.canGoPrevious : false
    readonly property bool mediaCanSeek: media ? media.canSeek : false
    readonly property bool mediaCanRaise: media ? media.canRaise : false
    readonly property real mediaLength: media ? media.length : 0
    readonly property real mediaPosition: media ? media.position : 0
    readonly property real mediaRate: media ? media.rate : 1
    function mediaPlayPause(): void { media?.playPause(); }
    function mediaNext(): void { media?.next(); }
    function mediaPrevious(): void { media?.previous(); }
    function mediaRaise(): void { media?.raise(); }
    function mediaSeek(microseconds: real): void { media?.seek(microseconds); }
    function mediaUpdatePosition(): void { media?.updatePosition(); }

    P5Support.DataSource {
        id: executable
        engine: "executable"
        onNewData: sourceName => disconnectSource(sourceName)
    }

    function openSettings(module: string): void {
        if (module.length > 0) {
            KCMUtils.KCMLauncher.openSystemSettings(module);
        } else {
            executable.connectSource("systemsettings");
        }
    }
}
