/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import org.kernora.system
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "m3"

Item {
    id: root

    required property QtObject backend
    property real progress: 1

    readonly property alias handleArea: handleArea

    signal requestClose()
    signal handleDragStarted()
    signal handleDragMoved(real upwards)
    signal handleDragEnded()

    readonly property bool scrollable: scroller.interactive
    property string detail: ""
    property bool editing: false

    onProgressChanged: {
        if (progress <= 0) {
            detail = "";
            editing = false;
        }
    }

    function scrollToTop(): void {
        scroller.contentY = 0;
    }

    implicitWidth: 412
    implicitHeight: handleArea.height + content.implicitHeight + 16

    function stage(start: real): real {
        const t = Math.max(0, Math.min(1, (progress - start) / (1 - start)));
        return 1 - Math.pow(1 - t, 3);
    }

    Kirigami.ShadowedRectangle {
        id: surface
        anchors.fill: parent
        readonly property var shadowSpec: M3.elevationOf("sheet")
        radius: M3.cornerSheet
        color: M3.surfaceContainer
        shadow.size: shadowSpec.blur
        shadow.yOffset: shadowSpec.offset
        shadow.color: Qt.rgba(0, 0, 0, shadowSpec.opacity)
    }

    Item {
        id: handleArea
        anchors.left: parent.left
        anchors.right: parent.right
        height: 28

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 12
            width: 32
            height: 4
            radius: 2
            color: M3.surfaceVariantContent
            opacity: 0.4
        }

        DragHandler {
            enabled: root.scrollable
            target: null
            xAxis.enabled: false
            dragThreshold: 8
            onActiveChanged: active ? root.handleDragStarted() : root.handleDragEnded()
            onTranslationChanged: {
                if (active) {
                    root.handleDragMoved(-translation.y);
                }
            }
        }
    }

    Flickable {
        id: scroller
        anchors.top: handleArea.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        contentWidth: width
        contentHeight: content.implicitHeight
        interactive: contentHeight > height + 1
        clip: interactive
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: content
            x: 16
            width: scroller.width - 32
            spacing: 16

            Loader {
                Layout.fillWidth: true
                active: root.detail.length > 0
                visible: active
                opacity: active ? 1 : 0
                sourceComponent: root.detail === "internet" ? internetPanel : root.detail === "bluetooth" ? bluetoothPanel : root.detail === "quickshare" ? quickSharePanel : null
            }

            ColumnLayout {
            Layout.fillWidth: true
            visible: root.detail.length === 0
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                opacity: root.stage(0.15)

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    spacing: 0

                    MText {
                        role: "headlineLarge"
                        text: root.backend.timeText
                    }
                    MText {
                        Layout.fillWidth: true
                        role: "bodyMedium"
                        color: M3.surfaceVariantContent
                        text: root.backend.dateText
                    }
                }

                Rectangle {
                    visible: root.backend.hasBattery
                    Layout.preferredHeight: 32
                    Layout.preferredWidth: batteryRow.implicitWidth + 20
                    Layout.alignment: Qt.AlignVCenter
                    Layout.rightMargin: 4
                    radius: M3.radius("chip", height)
                    color: M3.surfaceContainerHighest

                    Row {
                        id: batteryRow
                        anchors.centerIn: parent
                        spacing: 4
                        MIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            size: 18
                            source: root.backend.batteryIcon
                            color: root.backend.charging ? M3.primary : M3.surfaceVariantContent
                        }
                        MText {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "labelLarge"
                            text: i18nc("battery charge", "%1%", root.backend.batteryPercent)
                        }
                    }
                }

                MIconButton {
                    icon: "document-edit"
                    text: i18n("Edit tiles")
                    variant: root.editing ? "tonal" : "standard"
                    onClicked: root.editing = !root.editing
                }
                MIconButton {
                    icon: "configure"
                    text: i18n("System Settings")
                    onClicked: {
                        root.backend.openSettings("");
                        root.requestClose();
                    }
                }
                MIconButton {
                    id: powerButton
                    icon: "system-shutdown"
                    variant: "tonal"
                    checkable: true
                    text: i18n("Power")
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: powerButton.checked ? sessionFlow.implicitHeight : 0
                Layout.topMargin: powerButton.checked ? 0 : -16
                clip: true
                opacity: powerButton.checked ? 1 : 0

                Behavior on Layout.preferredHeight {
                    NumberAnimation {
                        duration: M3.durationMedium4
                        easing.type: Easing.Bezier
                        easing.bezierCurve: M3.easingEmphasized
                    }
                }
                Behavior on Layout.topMargin {
                    NumberAnimation {
                        duration: M3.durationMedium4
                        easing.type: Easing.Bezier
                        easing.bezierCurve: M3.easingEmphasized
                    }
                }
                Behavior on opacity { NumberAnimation { duration: M3.durationMedium2 } }

                Grid {
                    id: sessionFlow
                    width: parent.width
                    columns: 2
                    columnSpacing: 8
                    rowSpacing: 8

                    readonly property real cell: (width - columnSpacing) / 2

                    MButton {
                        width: sessionFlow.cell
                        variant: "tonal"
                        icon: "system-lock-screen"
                        text: i18n("Lock")
                        visible: root.backend.canLock
                        onClicked: { root.requestClose(); root.backend.lock(); }
                    }
                    MButton {
                        width: sessionFlow.cell
                        variant: "tonal"
                        icon: "system-suspend"
                        text: i18n("Sleep")
                        visible: root.backend.canSuspend
                        onClicked: { root.requestClose(); root.backend.suspend(); }
                    }
                    MButton {
                        width: sessionFlow.cell
                        variant: "tonal"
                        icon: "system-log-out"
                        text: i18n("Log Out")
                        visible: root.backend.canLogout
                        onClicked: { root.requestClose(); root.backend.logout(); }
                    }
                    MButton {
                        width: sessionFlow.cell
                        variant: "tonal"
                        icon: "system-reboot"
                        text: i18n("Restart")
                        visible: root.backend.canReboot
                        onClicked: { root.requestClose(); root.backend.reboot(); }
                    }
                    MButton {
                        width: sessionFlow.cell
                        variant: "filled"
                        icon: "system-shutdown"
                        text: i18n("Shut Down")
                        visible: root.backend.canShutdown
                        onClicked: { root.requestClose(); root.backend.shutdown(); }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                opacity: root.stage(0.3)
                transform: Translate { y: (1 - root.stage(0.3)) * 24 }

                MSlider {
                    Layout.fillWidth: true
                    visible: root.backend.brightnessAvailable
                    icon: "video-display-brightness"
                    text: i18n("Brightness")
                    from: 0
                    to: root.backend.brightnessMax
                    stepSize: Math.max(1, root.backend.brightnessMax / 100)
                    value: root.backend.brightness
                    onMoved: value => root.backend.setBrightness(value)
                }
                MSlider {
                    Layout.fillWidth: true
                    enabled: root.backend.soundAvailable
                    icon: root.backend.volumeIcon
                    text: i18n("Volume")
                    from: 0
                    to: root.backend.volumeMax
                    stepSize: root.backend.volumeMax / 100
                    value: root.backend.soundMuted ? 0 : root.backend.volume
                    onMoved: value => root.backend.setVolume(value)
                }
            }

            TileGrid {
                id: tileGrid
                Layout.fillWidth: true
                Layout.bottomMargin: root.backend.mediaActive || root.editing ? 0 : 8
                editing: root.editing
                tiles: root.tileComponents
                names: root.tileNames
                opacity: root.stage(0.45)
                transform: Translate { y: (1 - root.stage(0.45)) * 32 }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 8
                visible: root.editing
                spacing: 8
                Item { Layout.fillWidth: true }
                MButton {
                    variant: "text"
                    text: i18n("Reset")
                    onClicked: tileGrid.reset()
                }
                MButton {
                    variant: "filled"
                    text: i18n("Done")
                    onClicked: root.editing = false
                }
            }

            MediaCard {
                Layout.fillWidth: true
                Layout.bottomMargin: 8
                visible: root.backend.mediaActive
                backend: root.backend
                opacity: root.stage(0.6)
                transform: Translate { y: (1 - root.stage(0.6)) * 40 }
                onRequestClose: root.requestClose()
            }
            }
        }
    }

    readonly property var tileNames: ({
        internet: i18n("Internet"),
        bluetooth: i18n("Bluetooth"),
        sound: i18n("Sound"),
        mic: i18n("Microphone"),
        dnd: i18n("Do Not Disturb"),
        night: i18n("Night Light"),
        airplane: i18n("Airplane Mode"),
        awake: i18n("Keep Awake"),
        dark: i18n("Dark Theme"),
        screenshot: i18n("Screenshot"),
        quickshare: i18n("Quick Share")
    })

    readonly property var tileComponents: ({
        internet: internetTile,
        bluetooth: bluetoothTile,
        sound: soundTile,
        mic: micTile,
        dnd: dndTile,
        night: nightTile,
        airplane: airplaneTile,
        awake: awakeTile,
        dark: darkTile,
        screenshot: screenshotTile,
        quickshare: quickshareTile
    })

    Component {
        id: internetPanel
        InternetPanel {
            backend: root.backend
            onBack: root.detail = ""
            onRequestClose: root.requestClose()
        }
    }
    Component {
        id: quickSharePanel
        QuickSharePanel {
            backend: root.backend
            onBack: root.detail = ""
            onRequestClose: root.requestClose()
        }
    }
    Component {
        id: bluetoothPanel
        BluetoothPanel {
            backend: root.backend
            onBack: root.detail = ""
            onRequestClose: root.requestClose()
        }
    }

    Component {
        id: internetTile
        MTile {
            icon: root.backend.internetIcon
            title: i18n("Internet")
            subtitle: root.backend.internetSubtitle
            available: root.backend.internetAvailable
            checked: root.backend.internetOn
            hasDetails: true
            onToggled: root.backend.internetToggles ? root.backend.toggleInternet() : root.detail = "internet"
            onDetailsRequested: root.detail = "internet"
        }
    }
    Component {
        id: bluetoothTile
        MTile {
            icon: root.backend.btOn ? "bluetooth" : "bluetooth-disabled"
            iconOn: "kernora-tile-bluetooth-on"
            title: i18n("Bluetooth")
            subtitle: root.backend.btSubtitle
            available: root.backend.btAvailable
            checked: root.backend.btOn
            hasDetails: true
            onToggled: root.backend.toggleBluetooth()
            onDetailsRequested: root.detail = "bluetooth"
        }
    }
    Component {
        id: soundTile
        MTile {
            icon: root.backend.soundMuted ? "audio-volume-muted" : "audio-volume-high"
            title: i18n("Sound")
            subtitle: root.backend.soundMuted ? i18n("Muted") : root.backend.outputName
            available: root.backend.soundAvailable
            checked: !root.backend.soundMuted
            hasDetails: true
            onToggled: root.backend.toggleMute()
            onDetailsRequested: { root.backend.openSettings("kcm_pulseaudio"); root.requestClose(); }
        }
    }
    Component {
        id: micTile
        MTile {
            icon: root.backend.micMuted ? "microphone-sensitivity-muted" : "audio-input-microphone"
            title: i18n("Microphone")
            subtitle: root.backend.micMuted ? i18n("Muted") : i18n("On")
            available: root.backend.micAvailable
            checked: !root.backend.micMuted
            onToggled: root.backend.toggleMic()
        }
    }
    Component {
        id: dndTile
        MTile {
            icon: "notifications-disabled"
            iconOn: "kernora-tile-dnd-on"
            title: i18n("Do Not Disturb")
            subtitle: root.backend.dndOn ? i18n("On") : i18n("Off")
            available: root.backend.dndAvailable
            checked: root.backend.dndOn
            hasDetails: true
            onToggled: root.backend.toggleDnd()
            onDetailsRequested: { root.backend.openSettings("kcm_notifications"); root.requestClose(); }
        }
    }
    Component {
        id: nightTile
        MTile {
            icon: "redshift-status-on"
            iconOn: "kernora-tile-nightlight-on"
            title: i18n("Night Light")
            subtitle: root.backend.nightSubtitle
            available: root.backend.nightAvailable
            checked: root.backend.nightOn
            hasDetails: true
            onToggled: {
                if (root.backend.nightNeedsSetup) {
                    root.requestClose();
                }
                root.backend.toggleNight();
            }
            onDetailsRequested: { root.backend.openSettings("kcm_nightlight"); root.requestClose(); }
        }
    }
    Component {
        id: airplaneTile
        MTile {
            icon: "airplane-mode"
            iconOn: "kernora-tile-airplane-on"
            title: i18n("Airplane Mode")
            subtitle: root.backend.airplaneOn ? i18n("On") : i18n("Off")
            available: root.backend.airplaneAvailable
            checked: root.backend.airplaneOn
            onToggled: root.backend.toggleAirplane()
        }
    }
    Component {
        id: awakeTile
        MTile {
            icon: "kernora-tile-caffeine"
            iconOn: "kernora-tile-caffeine-on"
            title: i18n("Keep Awake")
            subtitle: root.backend.awakeOn ? i18n("Sleep blocked") : i18n("Off")
            available: root.backend.awakeAvailable
            checked: root.backend.awakeOn
            onToggled: root.backend.toggleAwake()
        }
    }
    Component {
        id: darkTile
        MTile {
            icon: "kernora-tile-darktheme"
            iconOn: "kernora-tile-darktheme-on"
            title: i18n("Dark Theme")
            subtitle: root.backend.themeBusy ? i18n("Switching…") : root.backend.darkOn ? i18n("On") : i18n("Off")
            available: root.backend.themeAvailable
            checked: root.backend.darkOn
            hasDetails: true
            onToggled: root.backend.toggleDark()
            onDetailsRequested: { root.backend.openSettings("appearance"); root.requestClose(); }
        }
    }
    Component {
        id: quickshareTile
        MTile {
            readonly property string mode: QuickShare.visibility
            icon: "kernora-quickshare"
            iconOn: "kernora-tile-quickshare-on"
            title: i18n("Quick Share")
            subtitle: !QuickShare.enabled ? i18n("Off")
                : mode === "temporary" ? i18n("Everyone, %1", QuickShare.visibleFor > 60
                    ? i18nc("minutes left, short", "%1m", Math.ceil(QuickShare.visibleFor / 60))
                    : i18nc("seconds left, short", "%1s", Math.max(1, QuickShare.visibleFor)))
                : mode === "everyone" ? i18n("Everyone")
                : i18n("Hidden")
            available: QuickShare.available
            checked: QuickShare.enabled
            hasDetails: true
            onToggled: QuickShare.setEnabled(!QuickShare.enabled)
            onDetailsRequested: root.detail = "quickshare"
        }
    }
    Component {
        id: screenshotTile
        MTile {
            icon: "applets-screenshooter"
            title: i18n("Screenshot")
            checked: false
            onToggled: {
                root.requestClose();
                root.backend.takeScreenshot();
            }
        }
    }

    MScrollIndicator {
        flickable: scroller
        visible: scroller.interactive
    }
}
