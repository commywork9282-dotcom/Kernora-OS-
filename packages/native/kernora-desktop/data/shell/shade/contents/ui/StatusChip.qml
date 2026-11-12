/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.pipewire.monitor as Monitor
import org.kde.plasma.private.volume as PA
import org.kernora.bartint
import "m3"

Item {
    id: root

    required property QtObject controller
    required property QtObject backend

    readonly property alias mediaPill: nowPlaying

    signal mediaRequested()

    readonly property bool active: controller.opening
    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool bar: Plasmoid.location === PlasmaCore.Types.TopEdge && !vertical
    readonly property bool clear: bar && !(Plasmoid.containmentDisplayHints & PlasmaCore.Types.ContainmentPrefersOpaqueBackground)
    readonly property bool darkInk: clear && BarTint.darkInk(Screen.name, "right")
    readonly property bool showMedia: bar && backend.mediaActive && backend.mediaTrack.length > 0
    readonly property bool micInUse: bar && recording.count > 0
    readonly property bool cameraInUse: bar && cameras.runningCount > 0
    readonly property bool showPrivacy: micInUse || cameraInUse
    readonly property real mediaSpace: (showMedia ? nowPlaying.width + 6 : 0) + (showPrivacy ? privacy.width + 6 : 0)
    readonly property string barNetworkIcon: {
        const name = backend.networkIcon;
        if (backend.network && backend.network.wiredConnected) {
            return "kernora-bar-ethernet";
        }
        if (!name.startsWith("network-wireless") || name.includes("offline") || name.includes("disabled")
                || name.includes("disconnected")) {
            return "kernora-bar-wifi-off";
        }
        if (name.includes("excellent") || name.includes("-100")) {
            return "kernora-bar-wifi-4";
        }
        if (name.includes("good") || name.includes("-75")) {
            return "kernora-bar-wifi-3";
        }
        if (name.includes("ok") || name.includes("-50")) {
            return "kernora-bar-wifi-2";
        }
        if (name.includes("weak") || name.includes("-25")) {
            return "kernora-bar-wifi-1";
        }
        if (name.includes("none") || name.includes("-00") || name.includes("acquiring")) {
            return "kernora-bar-wifi-0";
        }
        return "kernora-bar-wifi-4";
    }
    readonly property bool twelveHour: !backend.timeFormat.includes("H")
    readonly property string hourText: {
        const hour = backend.now.getHours();
        return twelveHour ? String(hour % 12 || 12) : String(hour).padStart(2, "0");
    }

    Layout.minimumWidth: vertical ? 0 : implicitWidth
    Layout.preferredWidth: vertical ? -1 : implicitWidth
    Layout.maximumWidth: vertical ? Number.POSITIVE_INFINITY : implicitWidth
    Layout.minimumHeight: vertical ? implicitHeight : 0
    Layout.preferredHeight: vertical ? implicitHeight : -1
    Layout.maximumHeight: vertical ? implicitHeight : Number.POSITIVE_INFINITY
    Layout.fillHeight: !vertical
    Layout.fillWidth: vertical
    implicitWidth: vertical ? 40 : bar ? mediaSpace + barContent.implicitWidth + 20 : content.implicitWidth + 32
    implicitHeight: vertical ? column.implicitHeight + 28 : 40

    Accessible.role: Accessible.Button
    Accessible.name: i18n("Quick Settings")
    Accessible.description: backend.timeText

    Rectangle {
        id: pill
        x: root.vertical ? Math.round((parent.width - width) / 2) : root.mediaSpace
        y: root.vertical ? 0 : Math.round((parent.height - height) / 2)
        width: root.vertical ? Math.min(parent.width, 40) : parent.width - root.mediaSpace
        height: root.vertical ? parent.height : Math.min(parent.height, root.bar ? 28 : 40)
        radius: Math.min(width, height) / 2
        color: root.bar ? (root.active ? M3.primary : "transparent") : root.active ? M3.secondaryContainer : M3.surfaceContainerHighest

        Behavior on color {
            ColorAnimation {
                duration: M3.durationMedium2
                easing.type: Easing.Bezier
                easing.bezierCurve: M3.easingEmphasized
            }
        }

        readonly property color ink: root.bar
            ? (root.active ? M3.primaryContent : root.clear ? BarTint.ink(Screen.name, "right") : M3.surfaceContent)
            : root.active ? M3.secondaryContainerContent : M3.surfaceContent
        readonly property color knockout: root.bar && !root.active && root.clear ? (root.darkInk ? BarTint.light : "#1b1b1f") : root.active ? M3.primary : M3.surface

        RowLayout {
            id: content
            anchors.centerIn: parent
            spacing: 8
            visible: !root.vertical && !root.bar

            MIcon {
                size: 20
                source: root.backend.networkIcon
                color: pill.ink
            }
            MIcon {
                size: 20
                source: root.backend.volumeIcon
                color: pill.ink
            }
            MIcon {
                size: 20
                visible: root.backend.hasBattery
                source: root.backend.batteryIcon
                color: pill.ink
            }
            MText {
                Layout.leftMargin: 4
                role: "labelLarge"
                text: root.backend.timeText
                color: pill.ink
            }
        }

        RowLayout {
            id: barContent
            anchors.centerIn: parent
            spacing: 6
            visible: root.bar

            MIcon {
                size: 18
                visible: root.backend.dndOn
                source: "kernora-bar-dnd"
                color: pill.ink
            }
            MIcon {
                size: 18
                visible: root.backend.soundMuted && root.backend.soundAvailable
                source: "kernora-bar-volume-off"
                color: pill.ink
            }
            MIcon {
                size: 18
                source: root.barNetworkIcon
                color: pill.ink
            }
            BatteryPill {
                Layout.leftMargin: 2
                visible: root.backend.hasBattery
                percent: root.backend.batteryPercent
                charging: root.backend.charging
                ink: pill.ink
                knockout: pill.knockout
            }
        }

        ColumnLayout {
            id: column
            anchors.centerIn: parent
            spacing: 6
            visible: root.vertical

            MIcon {
                Layout.alignment: Qt.AlignHCenter
                size: 20
                source: root.backend.networkIcon
                color: pill.ink
            }
            MIcon {
                Layout.alignment: Qt.AlignHCenter
                size: 20
                source: root.backend.volumeIcon
                color: pill.ink
            }
            MIcon {
                Layout.alignment: Qt.AlignHCenter
                size: 20
                visible: root.backend.hasBattery
                source: root.backend.batteryIcon
                color: pill.ink
            }
            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 2
                spacing: -4
                MText {
                    Layout.alignment: Qt.AlignHCenter
                    role: "labelLarge"
                    text: root.hourText
                    color: pill.ink
                }
                MText {
                    Layout.alignment: Qt.AlignHCenter
                    role: "labelLarge"
                    text: Qt.formatTime(root.backend.now, "mm")
                    color: pill.ink
                }
            }
        }

        MStateLayer {
            radius: pill.radius
            color: pill.ink
            hovered: mouse.containsMouse && mouse.mouseX >= root.mediaSpace
            pressed: mouse.pressed && !root.controller.dragging && mouse.mouseX >= root.mediaSpace
            pressPoint: Qt.point(mouse.mouseX - pill.x, mouse.mouseY - pill.y)
        }
    }

    Rectangle {
        id: nowPlaying
        visible: root.showMedia
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(220, mediaRow.implicitWidth + 20)
        height: 28
        radius: 14
        color: root.clear ? Qt.rgba(0.07, 0.07, 0.08, 0.9) : M3.surfaceContainerHighest
        border.width: root.clear ? 1 : 0
        border.color: Qt.rgba(1, 1, 1, 0.18)

        readonly property color ink: root.clear ? "#ffffff" : M3.surfaceContent

        MStateLayer {
            radius: nowPlaying.radius
            color: nowPlaying.ink
            hovered: mouse.containsMouse && mouse.mouseX < nowPlaying.width
            pressed: mouse.pressed && mouse.mouseX < nowPlaying.width
        }

        RowLayout {
            id: mediaRow
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                radius: 10
                color: playToggle.containsMouse ? M3.primary : "transparent"

                Kirigami.Icon {
                    anchors.fill: parent
                    visible: !playToggle.containsMouse
                    source: root.backend.mediaIconName || "audio-x-generic"
                }
                MIcon {
                    anchors.centerIn: parent
                    visible: playToggle.containsMouse
                    size: 16
                    source: root.backend.mediaPlaying ? "media-playback-pause" : "media-playback-start"
                    color: M3.primaryContent
                }
            }
            MText {
                Layout.fillWidth: true
                Layout.maximumWidth: 160
                role: "labelLarge"
                color: nowPlaying.ink
                elide: Text.ElideRight
                text: root.backend.mediaTrack
            }
        }
    }

    PA.PulseObjectFilterModel {
        id: recording
        filters: [{ role: "VirtualStream", value: false }]
        sourceModel: PA.SourceOutputModel {}
    }

    Monitor.MediaMonitor {
        id: cameras
        role: Monitor.MediaRole.Camera
    }

    onMicInUseChanged: privacy.reveal()
    onCameraInUseChanged: privacy.reveal()

    Rectangle {
        id: privacy

        property bool open: true

        function reveal(): void {
            open = true;
            collapse.restart();
        }

        visible: root.showPrivacy
        x: root.showMedia ? nowPlaying.width + 6 : 0
        anchors.verticalCenter: parent.verticalCenter
        width: open ? privacyRow.implicitWidth + 20 : 10
        height: open ? 28 : 10
        radius: height / 2
        color: "#3ddc84"

        Accessible.name: [root.cameraInUse ? i18n("Camera in use") : "", root.micInUse ? i18n("Microphone in use") : ""]
            .filter(part => part.length > 0).join(", ")

        Behavior on width {
            NumberAnimation { duration: M3.durationMedium2; easing.type: Easing.OutCubic }
        }
        Behavior on height {
            NumberAnimation { duration: M3.durationMedium2; easing.type: Easing.OutCubic }
        }

        Timer {
            id: collapse
            interval: 5000
            onTriggered: privacy.open = false
        }

        Row {
            id: privacyRow
            anchors.centerIn: parent
            spacing: 4
            opacity: privacy.open ? 1 : 0

            Behavior on opacity {
                NumberAnimation { duration: M3.durationShort4 }
            }

            MIcon {
                visible: root.cameraInUse
                size: 18
                source: "kernora-bar-camera"
                color: "#00210b"
            }
            MIcon {
                visible: root.micInUse
                size: 18
                source: "kernora-bar-mic"
                color: "#00210b"
            }
        }
    }

    MouseArea {
        id: mouse

        property real pressY: 0
        property bool draggingShade: false

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: draggingShade ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        preventStealing: true

        onPressed: event => {
            pressY = event.y;
            draggingShade = false;
        }
        onPositionChanged: event => {
            if (!pressed) {
                return;
            }
            const upwards = pressY - event.y;
            if (!draggingShade && Math.abs(upwards) > Qt.styleHints.startDragDistance) {
                draggingShade = true;
                root.controller.beginDrag();
            }
            if (draggingShade) {
                root.controller.dragTo(upwards);
            }
        }
        onReleased: {
            if (draggingShade) {
                draggingShade = false;
                root.controller.endDrag();
            } else if (root.showMedia && mouseX < nowPlaying.x + nowPlaying.width) {
                root.mediaRequested();
            } else {
                root.controller.toggle();
            }
        }
        onCanceled: {
            if (draggingShade) {
                draggingShade = false;
                root.controller.cancelDrag();
            }
        }
    }

    MouseArea {
        id: playToggle
        visible: root.showMedia && root.backend.mediaCanPlayPause
        x: nowPlaying.x + 2
        y: nowPlaying.y + 2
        width: 28
        height: nowPlaying.height - 4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.backend.mediaPlayPause()
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            if (event.pixelDelta.y !== 0) {
                root.controller.scrollBy(event.inverted ? -event.pixelDelta.y : event.pixelDelta.y);
            } else if (event.angleDelta.y !== 0) {
                const up = event.inverted ? -event.angleDelta.y : event.angleDelta.y;
                root.controller.wheelNotch(up > 0);
            }
        }
    }
}
