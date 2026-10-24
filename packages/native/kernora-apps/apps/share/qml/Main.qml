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

    width: 560
    height: 460
    minimumWidth: 480
    minimumHeight: 420
    color: M3.surfaceContainer
    visible: true
    title: i18n("Quick Share")

    readonly property var files: startArguments.filter(argument => !argument.startsWith("--"))
    readonly property var devices: QuickShare.devices
    property var target: null
    property string transferId: ""
    readonly property var transfer: transferId.length > 0 ? (QuickShare.transfers.find(t => t.id === transferId) || null) : null
    readonly property bool confirming: target !== null && transferId.length > 0
    readonly property string phase: transfer ? transfer.phase : (confirming ? "connecting" : "")
    readonly property bool failed: ["rejected", "failed"].includes(phase)

    readonly property string firstName: files.length > 0 ? fileName(files[0]) : ""
    readonly property bool singleImage: files.length === 1 && /\.(png|jpe?g|gif|webp|bmp|avif)$/i.test(firstName)

    function fileName(path: string): string {
        const parts = String(path).split("/");
        return decodeURIComponent(parts[parts.length - 1] || path);
    }

    function deviceIcon(kind: string): string {
        return kind === "computer" ? "computer" : "phone";
    }

    function next(): void {
        if (!app.target) {
            return;
        }
        app.transferId = "pending";
        QuickShare.send(app.target.id, app.files, id => {
            if (id.length === 0) {
                app.transferId = "";
                app.showMessage(i18n("Could not send to %1", app.target.name), "", null);
                return;
            }
            app.transferId = id;
        });
    }

    function cancel(): void {
        if (app.transfer && !app.failed && app.phase !== "finished") {
            QuickShare.cancel(app.transfer.id);
        }
        app.close();
    }

    onPhaseChanged: {
        if (phase === "transferring" || phase === "finished" || phase === "cancelled") {
            app.close();
        }
    }

    Component.onCompleted: QuickShare.startDiscovery()
    onClosing: QuickShare.stopDiscovery()

    Timer {
        interval: 30000
        repeat: true
        running: !app.confirming
        onTriggered: QuickShare.startDiscovery()
    }

    component Preview: Rectangle {
        implicitWidth: 132
        implicitHeight: 148
        radius: M3.classic ? M3.cornerCard : 24
        color: M3.surfaceContainerHighest

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                RoundedClip {
                    anchors.fill: parent
                    radius: 12
                    visible: app.singleImage && thumbnail.status === Image.Ready
                    Image {
                        id: thumbnail
                        anchors.fill: parent
                        source: app.singleImage ? app.files[0] : ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 256
                        asynchronous: true
                    }
                }
                IconCircle {
                    anchors.centerIn: parent
                    visible: !(app.singleImage && thumbnail.status === Image.Ready)
                    size: 56
                    icon: app.files.length === 1 ? Files.iconName(app.files[0]) : "folder-documents"
                    containerColor: M3.secondaryContainer
                    contentColor: M3.secondaryContainerContent
                }
            }
            MText {
                Layout.fillWidth: true
                role: "labelLarge"
                color: M3.surfaceContent
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideMiddle
                text: app.files.length === 1 ? app.firstName : i18n("%1 Files", app.files.length)
            }
        }
    }

    component Pulse: Item {
        id: pulse
        property bool running: true
        Repeater {
            model: 3
            delegate: Rectangle {
                id: ring
                required property int index
                anchors.centerIn: parent
                width: pulse.width
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 2
                border.color: M3.primary
                opacity: 0
                scale: 0.4
                SequentialAnimation {
                    running: pulse.running && pulse.visible && M3.motionScale > 0
                    loops: Animation.Infinite
                    PauseAnimation { duration: ring.index * 700 }
                    ParallelAnimation {
                        NumberAnimation { target: ring; property: "scale"; from: 0.4; to: 1; duration: 2100; easing.type: Easing.OutCubic }
                        NumberAnimation { target: ring; property: "opacity"; from: 0.5; to: 0; duration: 2100; easing.type: Easing.InQuad }
                    }
                    PauseAnimation { duration: (2 - ring.index) * 700 }
                }
            }
        }
    }

    component DeviceRow: Rectangle {
        id: row
        required property var device
        readonly property bool selected: app.target !== null && app.target.id === device.id
        signal picked()

        implicitHeight: 60
        radius: 16
        color: selected ? M3.primaryContainer : "transparent"
        Behavior on color { ColorAnimation { duration: M3.durationMedium2 } }

        MStateLayer {
            anchors.fill: parent
            radius: row.radius
            color: row.selected ? M3.primaryContainerContent : M3.surfaceContent
            hovered: rowMouse.containsMouse
            pressed: rowMouse.pressed
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 14
            spacing: 12

            IconCircle {
                size: 40
                icon: app.deviceIcon(row.device.kind)
                containerColor: row.selected ? M3.primary : M3.secondaryContainer
                contentColor: row.selected ? M3.primaryContent : M3.secondaryContainerContent
            }
            MText {
                Layout.fillWidth: true
                role: "titleSmall"
                color: row.selected ? M3.primaryContainerContent : M3.surfaceContent
                text: row.device.name
                elide: Text.ElideRight
            }
            MIcon {
                visible: row.selected
                size: 20
                source: "dialog-positive"
                color: M3.primaryContainerContent
            }
        }
        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.picked()
            onDoubleClicked: {
                row.picked();
                app.next();
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 28
        anchors.rightMargin: 28
        anchors.topMargin: 28
        anchors.bottomMargin: 24
        spacing: 6

        MText {
            Layout.fillWidth: true
            role: "headlineSmall"
            color: M3.surfaceContent
            text: app.confirming ? i18n("Share with this device?") : i18n("Quick Share")
        }
        MText {
            Layout.fillWidth: true
            role: "bodyMedium"
            color: M3.surfaceVariantContent
            wrapMode: Text.Wrap
            visible: !app.confirming
            text: QuickShare.enabled ? i18n("Select the device you'd like to share files with")
                                     : i18n("Quick Share is turned off")
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 14

            RowLayout {
                anchors.fill: parent
                spacing: 24
                visible: !app.confirming

                Item {
                    Layout.preferredWidth: 180
                    Layout.fillHeight: true

                    Pulse {
                        anchors.centerIn: preview
                        width: 200
                        height: 200
                        running: QuickShare.enabled && app.devices.length === 0
                    }
                    Preview {
                        id: preview
                        anchors.centerIn: parent
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ListView {
                        anchors.fill: parent
                        clip: true
                        spacing: 4
                        model: app.devices
                        visible: app.devices.length > 0
                        delegate: DeviceRow {
                            required property var modelData
                            width: ListView.view.width
                            device: modelData
                            onPicked: app.target = modelData
                        }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        width: parent.width
                        spacing: 16
                        visible: app.devices.length === 0

                        MLoadingIndicator {
                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: 40
                            implicitHeight: 40
                            visible: QuickShare.enabled
                            running: visible
                        }
                        MText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            role: "bodyLarge"
                            color: M3.surfaceVariantContent
                            wrapMode: Text.Wrap
                            text: QuickShare.enabled ? i18n("Scanning for nearby devices…")
                                                     : i18n("Turn on Quick Share to see devices nearby.")
                        }
                        MButton {
                            Layout.alignment: Qt.AlignHCenter
                            visible: !QuickShare.enabled
                            variant: "tonal"
                            text: i18n("Turn on")
                            onClicked: {
                                QuickShare.setEnabled(true);
                                QuickShare.startDiscovery();
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 18
                visible: app.confirming

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 8
                    spacing: 28

                    Preview {}

                    MIcon {
                        size: 28
                        source: "go-next"
                        color: M3.surfaceVariantContent
                    }

                    Item {
                        implicitWidth: 132
                        implicitHeight: 148

                        Item {
                            id: target
                            width: 96
                            height: 96
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 6

                            Pulse {
                                anchors.centerIn: parent
                                width: 140
                                height: 140
                                running: !app.failed
                            }
                            MCircularProgress {
                                anchors.fill: parent
                                visible: !app.failed
                                running: visible
                            }
                            IconCircle {
                                anchors.centerIn: parent
                                size: 76
                                icon: app.failed ? "dialog-error" : app.deviceIcon(app.target ? app.target.kind : "")
                                containerColor: app.failed ? M3.errorContainer : M3.primaryContainer
                                contentColor: app.failed ? M3.errorContainerContent : M3.primaryContainerContent
                            }
                        }
                        MText {
                            anchors.top: target.bottom
                            anchors.topMargin: 12
                            width: parent.width
                            role: "labelLarge"
                            color: M3.surfaceContent
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: app.target ? app.target.name : ""
                        }
                    }
                }

                MText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    role: "titleMedium"
                    color: M3.surfaceContent
                    visible: !app.failed && app.transfer !== null && app.transfer.pin.length > 0
                    text: app.transfer ? i18n("Secure connection ID: %1", app.transfer.pin) : ""
                }
                MText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    role: "bodyMedium"
                    color: M3.surfaceVariantContent
                    visible: !app.failed
                    text: app.phase === "waiting" && app.target ? i18n("Waiting for %1 to accept…", app.target.name)
                                                                : i18n("Connecting…")
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: app.failed
                    spacing: 12

                    MIcon {
                        Layout.alignment: Qt.AlignTop
                        size: 20
                        source: "dialog-information"
                        color: M3.error
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        MText {
                            Layout.fillWidth: true
                            role: "titleSmall"
                            color: M3.error
                            text: i18n("Can't share")
                        }
                        MText {
                            Layout.fillWidth: true
                            role: "bodyMedium"
                            color: M3.surfaceVariantContent
                            wrapMode: Text.Wrap
                            text: app.phase === "rejected" ? i18n("The device you're trying to share with did not accept")
                                                           : i18n("Something went wrong. Please try again.")
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 8
            spacing: 12
            visible: !app.confirming

            MIcon {
                Layout.alignment: Qt.AlignTop
                size: 18
                source: "dialog-information"
                color: M3.surfaceVariantContent
            }
            MText {
                Layout.fillWidth: true
                role: "bodySmall"
                color: M3.surfaceVariantContent
                wrapMode: Text.Wrap
                text: i18n("Make sure both devices are unlocked, close together and on the same Wi-Fi. If a phone isn't listed, open Quick Share on it and choose Everyone.")
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 12
            spacing: 8

            Item {
                Layout.fillWidth: true
            }
            MButton {
                variant: "outlined"
                text: app.failed ? i18n("Close") : i18n("Cancel")
                onClicked: app.cancel()
            }
            MButton {
                visible: !app.confirming || app.failed
                enabled: app.failed || app.target !== null
                variant: "filled"
                text: app.failed ? i18n("Try again") : i18n("Next")
                onClicked: {
                    if (app.failed) {
                        app.transferId = "";
                        app.target = null;
                        QuickShare.startDiscovery();
                        return;
                    }
                    app.next();
                }
            }
        }
    }
}
