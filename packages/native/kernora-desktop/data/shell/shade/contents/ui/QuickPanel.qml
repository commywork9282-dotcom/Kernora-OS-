/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.workspace.keyboardlayout as Keyboards
import org.kernora.system
import "m3"

ColumnLayout {
    id: panel

    required property QtObject backend
    required property Item sheet

    property bool confirmReset: false
    property string versionText: ""

    spacing: 12

    Keyboards.KeyboardLayout {
        id: keyboard
    }

    readonly property var currentLayout: keyboard.layoutsList.length > keyboard.layout ? keyboard.layoutsList[keyboard.layout] : null

    P5Support.DataSource {
        id: version
        engine: "executable"
        connectedSources: [". /etc/os-release; printf '%s\\n' \"$PRETTY_NAME\"; dpkg-query -W -f='${Version}' kernora-desktop"]
        onNewData: (source, data) => {
            const lines = String(data.stdout || "").trim().split("\n");
            panel.versionText = lines.length > 1 ? i18nc("system name and build", "%1 (%2)", lines[0], lines[1]) : lines[0];
            disconnectSource(source);
        }
    }

    Connections {
        target: panel.sheet
        function onEditingChanged(): void {
            panel.confirmReset = false;
        }
    }

    component RoundButton: Item {
        id: round

        property string icon
        property string text
        property bool checked: false

        signal clicked()

        Layout.preferredWidth: 40
        Layout.preferredHeight: 40
        Layout.alignment: Qt.AlignVCenter
        Accessible.role: Accessible.Button
        Accessible.name: text
        activeFocusOnTab: true

        Rectangle {
            id: roundShape
            anchors.fill: parent
            radius: width / 2
            color: round.checked ? M3.primary : (M3.dark ? M3.surfaceContainer : M3.surfaceContainerLowest)
            Behavior on color { ColorAnimation { duration: M3.durationShort4 } }

            MIcon {
                anchors.centerIn: parent
                size: 20
                source: round.icon
                color: round.checked ? M3.primaryContent : M3.surfaceContent
            }
            MStateLayer {
                radius: roundShape.radius
                color: round.checked ? M3.primaryContent : M3.surfaceContent
                hovered: roundMouse.containsMouse
                pressed: roundMouse.pressed
                focused: round.activeFocus
                pressPoint: Qt.point(roundMouse.mouseX, roundMouse.mouseY)
            }
        }
        MouseArea {
            id: roundMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: round.clicked()
        }
        Keys.onReturnPressed: round.clicked()
        Keys.onSpacePressed: round.clicked()
    }

    RowLayout {
        Layout.fillWidth: true
        visible: !panel.sheet.editing
        spacing: 4
        opacity: panel.sheet.stage(0.15)

        MIconButton {
            icon: "kernora-tiles-edit"
            text: i18n("Edit tiles")
            onClicked: panel.sheet.editing = true
        }
        MIconButton {
            icon: "configure"
            text: i18n("Settings")
            onClicked: {
                panel.backend.openSettings("");
                panel.sheet.requestClose();
            }
        }
        Item {
            Layout.fillWidth: true
        }
        Item {
            id: powerButton
            Layout.preferredWidth: powerRow.implicitWidth + 20
            Layout.preferredHeight: 40
            Accessible.role: Accessible.ButtonMenu
            Accessible.name: i18n("Power")
            activeFocusOnTab: true

            Rectangle {
                id: powerShape
                anchors.fill: parent
                radius: height / 2
                color: powerMenu.opened ? M3.secondaryContainer : "transparent"

                Row {
                    id: powerRow
                    anchors.centerIn: parent
                    spacing: 2
                    MIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        size: 22
                        source: "system-shutdown"
                        color: M3.surfaceContent
                    }
                    MIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        size: 18
                        source: "arrow-down"
                        color: M3.surfaceContent
                    }
                }
                MStateLayer {
                    radius: powerShape.radius
                    color: M3.surfaceContent
                    hovered: powerMouse.containsMouse
                    pressed: powerMouse.pressed
                    focused: powerButton.activeFocus
                    pressPoint: Qt.point(powerMouse.mouseX, powerMouse.mouseY)
                }
            }
            MouseArea {
                id: powerMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: panel.openPowerMenu()
            }
            Keys.onReturnPressed: panel.openPowerMenu()
            Keys.onSpacePressed: panel.openPowerMenu()
        }
    }

    function openPowerMenu(): void {
        const items = [];
        if (panel.backend.canLock) {
            items.push({ icon: "system-lock-screen", text: i18n("Lock"), action: () => { panel.sheet.requestClose(); panel.backend.lock(); } });
        }
        if (panel.backend.canSuspend) {
            items.push({ icon: "system-suspend", text: i18n("Sleep"), action: () => { panel.sheet.requestClose(); panel.backend.suspend(); } });
        }
        if (panel.backend.canLogout) {
            items.push({ icon: "system-log-out", text: i18n("Sign out"), action: () => { panel.sheet.requestClose(); panel.backend.logout(); } });
        }
        if (panel.backend.canReboot) {
            items.push({ icon: "system-reboot", text: i18n("Restart"), action: () => { panel.sheet.requestClose(); panel.backend.reboot(); } });
        }
        if (panel.backend.canShutdown) {
            items.push({ icon: "system-shutdown", text: i18n("Power off"), action: () => { panel.sheet.requestClose(); panel.backend.shutdown(); } });
        }
        powerMenu.items = items;
        powerMenu.openAt(powerButton, powerButton.width - powerMenu.implicitWidth, powerButton.height + 4);
    }

    MMenu {
        id: powerMenu
        parent: panel.sheet
    }

    RowLayout {
        Layout.fillWidth: true
        visible: panel.sheet.editing
        spacing: 4

        MIconButton {
            icon: "go-previous"
            text: i18n("Done")
            onClicked: panel.sheet.editing = false
        }
        MText {
            Layout.fillWidth: true
            role: "titleLarge"
            text: i18n("Edit tiles")
            elide: Text.ElideRight
        }
        MIconButton {
            icon: "edit-undo"
            text: i18n("Undo")
            enabled: tileGrid.canUndo
            opacity: enabled ? 1 : 0.38
            onClicked: tileGrid.undo()
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: !panel.sheet.editing
        spacing: 8
        opacity: panel.sheet.stage(0.3)
        transform: Translate { y: (1 - panel.sheet.stage(0.3)) * 24 }

        RowLayout {
            Layout.fillWidth: true
            visible: panel.backend.brightnessAvailable
            spacing: 8

            MSlider {
                Layout.fillWidth: true
                googlebook: true
                trackHeight: 40
                icon: "kernora-brightness"
                text: i18n("Brightness")
                from: 0
                to: panel.backend.brightnessMax
                stepSize: Math.max(1, panel.backend.brightnessMax / 100)
                value: panel.backend.brightness
                onMoved: value => panel.backend.setBrightness(value)
            }
            RoundButton {
                visible: panel.backend.nightAvailable
                icon: "redshift-status-on"
                text: i18n("Night Light")
                checked: panel.backend.nightOn
                onClicked: {
                    if (panel.backend.nightNeedsSetup) {
                        panel.sheet.requestClose();
                    }
                    panel.backend.toggleNight();
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MSlider {
                Layout.fillWidth: true
                googlebook: true
                trackHeight: 40
                enabled: panel.backend.soundAvailable
                icon: panel.backend.soundMuted ? "audio-volume-muted" : "audio-x-generic"
                iconClickable: true
                text: i18n("Volume")
                from: 0
                to: panel.backend.volumeMax
                stepSize: panel.backend.volumeMax / 100
                value: panel.backend.soundMuted ? 0 : panel.backend.volume
                onMoved: value => panel.backend.setVolume(value)
                onIconClicked: panel.backend.toggleMute()
            }
            RoundButton {
                icon: "preferences-desktop"
                text: i18n("Sound devices")
                onClicked: panel.sheet.detail = "audio"
            }
        }
    }

    TileGrid {
        id: tileGrid
        Layout.fillWidth: true
        googlebook: true
        category: "GooglebookTiles"
        defaultLayout: [
            ["internet", 2], ["bluetooth", 2], ["screenshot", 2], ["dnd", 2],
            ["quickshare", 2], ["mic", 2], ["dark", 2], ["keyboard", 2]
        ]
        editing: panel.sheet.editing
        tiles: panel.tileComponents
        names: panel.tileNames
        opacity: panel.sheet.stage(0.45)
        transform: Translate { y: (1 - panel.sheet.stage(0.45)) * 32 }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: panel.sheet.editing && !panel.confirmReset
        MButton {
            variant: "text"
            text: i18n("Reset")
            onClicked: panel.confirmReset = true
        }
        Item {
            Layout.fillWidth: true
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: confirmColumn.implicitHeight + 32
        visible: panel.sheet.editing && panel.confirmReset
        radius: 24
        color: M3.dark ? M3.surfaceContainer : M3.surfaceContainerLowest

        ColumnLayout {
            id: confirmColumn
            anchors.fill: parent
            anchors.margins: 16
            spacing: 8

            MText {
                Layout.fillWidth: true
                role: "bodyMedium"
                wrapMode: Text.Wrap
                text: i18n("Reset tiles to the default order and size?")
            }
            RowLayout {
                Layout.fillWidth: true
                Item {
                    Layout.fillWidth: true
                }
                MButton {
                    variant: "text"
                    text: i18n("Cancel")
                    onClicked: panel.confirmReset = false
                }
                MButton {
                    variant: "filled"
                    text: i18n("OK")
                    onClicked: {
                        tileGrid.reset();
                        panel.confirmReset = false;
                    }
                }
            }
        }
    }

    MText {
        Layout.fillWidth: true
        Layout.leftMargin: 8
        visible: !panel.sheet.editing && panel.versionText.length > 0
        role: "bodySmall"
        color: M3.surfaceVariantContent
        text: panel.versionText
        elide: Text.ElideRight
    }

    readonly property var tileNames: ({
        internet: i18n("Wi-Fi"),
        bluetooth: i18n("Bluetooth"),
        screenshot: i18n("Screen capture"),
        dnd: i18n("Do Not Disturb"),
        quickshare: i18n("Quick Share"),
        mic: i18n("Mic access"),
        dark: i18n("Dark theme"),
        keyboard: i18n("Keyboard"),
        sound: i18n("Sound"),
        night: i18n("Night Light"),
        airplane: i18n("Airplane Mode"),
        awake: i18n("Keep Awake")
    })

    readonly property var tileComponents: ({
        internet: internetTile,
        bluetooth: bluetoothTile,
        screenshot: screenshotTile,
        dnd: dndTile,
        quickshare: quickshareTile,
        mic: micTile,
        dark: darkTile,
        keyboard: keyboardTile,
        sound: soundTile,
        night: nightTile,
        airplane: airplaneTile,
        awake: awakeTile
    })

    Component {
        id: internetTile
        MTile {
            icon: panel.backend.internetIcon
            title: panel.backend.wifiAvailable ? i18n("Wi-Fi") : i18n("Internet")
            subtitle: panel.backend.internetSubtitle
            available: panel.backend.internetAvailable
            checked: panel.backend.internetOn
            hasDetails: true
            onToggled: panel.backend.internetToggles ? panel.backend.toggleInternet() : panel.sheet.detail = "internet"
            onDetailsRequested: panel.sheet.detail = "internet"
        }
    }
    Component {
        id: bluetoothTile
        MTile {
            icon: panel.backend.btOn ? "bluetooth" : "bluetooth-disabled"
            iconOn: "kernora-tile-bluetooth-on"
            title: i18n("Bluetooth")
            subtitle: panel.backend.btSubtitle
            available: panel.backend.btAvailable
            checked: panel.backend.btOn
            hasDetails: true
            onToggled: panel.backend.toggleBluetooth()
            onDetailsRequested: panel.sheet.detail = "bluetooth"
        }
    }
    Component {
        id: screenshotTile
        MTile {
            icon: "kernora-screen-capture"
            title: i18n("Screen capture")
            checked: false
            onToggled: {
                panel.sheet.requestClose();
                panel.backend.takeScreenshot();
            }
        }
    }
    Component {
        id: dndTile
        MTile {
            icon: "dnd"
            iconOn: "kernora-tile-dnd-on"
            title: i18n("Do Not Disturb")
            subtitle: panel.backend.dndOn ? i18n("On") : i18n("Off")
            available: panel.backend.dndAvailable
            checked: panel.backend.dndOn
            hasDetails: true
            onToggled: panel.backend.toggleDnd()
            onDetailsRequested: {
                panel.backend.openSettings("notifications");
                panel.sheet.requestClose();
            }
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
            onToggled: panel.sheet.detail = "quickshare"
        }
    }
    Component {
        id: micTile
        MTile {
            icon: panel.backend.micMuted ? "kernora-tile-mic-off" : "audio-input-microphone"
            title: i18n("Mic access")
            subtitle: panel.backend.micMuted ? i18nc("microphone state", "Blocked") : i18nc("microphone state", "Available")
            available: panel.backend.micAvailable
            checked: !panel.backend.micMuted
            onToggled: panel.backend.toggleMic()
        }
    }
    Component {
        id: darkTile
        MTile {
            icon: "kernora-tile-darktheme"
            title: i18n("Dark theme")
            subtitle: panel.backend.themeBusy ? i18n("Switching…") : ""
            available: panel.backend.themeAvailable
            checked: panel.backend.darkOn
            onToggled: panel.backend.toggleDark()
        }
    }
    Component {
        id: keyboardTile
        MTile {
            icon: "input-keyboard"
            title: i18n("Keyboard")
            subtitle: panel.currentLayout ? (panel.currentLayout.longName || panel.currentLayout.displayName || panel.currentLayout.shortName) : ""
            checked: false
            onToggled: panel.sheet.detail = "keyboard"
        }
    }
    Component {
        id: soundTile
        MTile {
            icon: panel.backend.soundMuted ? "audio-volume-muted" : "audio-volume-high"
            title: i18n("Sound")
            subtitle: panel.backend.soundMuted ? i18n("Muted") : panel.backend.outputName
            available: panel.backend.soundAvailable
            checked: !panel.backend.soundMuted
            hasDetails: true
            onToggled: panel.backend.toggleMute()
            onDetailsRequested: panel.sheet.detail = "audio"
        }
    }
    Component {
        id: nightTile
        MTile {
            icon: "redshift-status-on"
            iconOn: "kernora-tile-nightlight-on"
            title: i18n("Night Light")
            subtitle: panel.backend.nightSubtitle
            available: panel.backend.nightAvailable
            checked: panel.backend.nightOn
            onToggled: {
                if (panel.backend.nightNeedsSetup) {
                    panel.sheet.requestClose();
                }
                panel.backend.toggleNight();
            }
        }
    }
    Component {
        id: airplaneTile
        MTile {
            icon: "airplane-mode"
            iconOn: "kernora-tile-airplane-on"
            title: i18n("Airplane Mode")
            subtitle: panel.backend.airplaneOn ? i18n("On") : i18n("Off")
            available: panel.backend.airplaneAvailable
            checked: panel.backend.airplaneOn
            onToggled: panel.backend.toggleAirplane()
        }
    }
    Component {
        id: awakeTile
        MTile {
            icon: "kernora-tile-caffeine"
            iconOn: "kernora-tile-caffeine-on"
            title: i18n("Keep Awake")
            subtitle: panel.backend.awakeOn ? i18n("Sleep blocked") : i18n("Off")
            available: panel.backend.awakeAvailable
            checked: panel.backend.awakeOn
            onToggled: panel.backend.toggleAwake()
        }
    }
}
