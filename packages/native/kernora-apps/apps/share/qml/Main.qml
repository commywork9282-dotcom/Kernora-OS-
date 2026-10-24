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

    width: 480
    height: 600
    minimumWidth: 380
    minimumHeight: 480
    color: M3.surfaceContainer
    visible: true
    title: i18n("Quick Share")

    readonly property var files: startArguments.filter(argument => !argument.startsWith("--"))
    property var sent: ({})
    readonly property var transfers: QuickShare.transfers
    readonly property var devices: QuickShare.devices

    function transferFor(device: string): var {
        const id = sent[device];
        if (!id) {
            return null;
        }
        return transfers.find(t => t.id === id) || null;
    }

    function fileName(path: string): string {
        const parts = String(path).split("/");
        return decodeURIComponent(parts[parts.length - 1] || path);
    }

    function sendTo(device: var): void {
        const current = transferFor(device.id);
        if (current && !["finished", "rejected", "cancelled", "failed"].includes(current.phase)) {
            return;
        }
        QuickShare.send(device.id, files, id => {
            if (id.length === 0) {
                app.showMessage(i18n("Could not send to %1", device.name), "", null);
                return;
            }
            const next = Object.assign({}, app.sent);
            next[device.id] = id;
            app.sent = next;
        });
    }

    function status(transfer: var): string {
        if (!transfer) {
            return "";
        }
        switch (transfer.phase) {
        case "connecting":
            return i18n("Connecting…");
        case "waiting":
            return transfer.pin.length > 0 ? i18n("Waiting to accept · PIN %1", transfer.pin) : i18n("Waiting to accept");
        case "transferring":
            return transfer.total > 0 ? i18n("Sending %1%", Math.round(100 * transfer.done / transfer.total)) : i18n("Sending…");
        case "finished":
            return i18n("Sent");
        case "rejected":
            return i18n("Declined");
        case "cancelled":
            return i18n("Cancelled");
        default:
            return i18n("Not sent");
        }
    }

    Component.onCompleted: QuickShare.startDiscovery()
    onClosing: QuickShare.stopDiscovery()

    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: QuickShare.startDiscovery()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 20

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            IconCircle {
                icon: "kernora-quickshare"
                size: 56
                containerColor: M3.primaryContainer
                contentColor: M3.primaryContainerContent
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                MText {
                    Layout.fillWidth: true
                    role: "titleLarge"
                    text: i18n("Quick Share")
                    color: M3.surfaceContent
                }
                MText {
                    Layout.fillWidth: true
                    role: "bodyMedium"
                    color: M3.surfaceVariantContent
                    elide: Text.ElideMiddle
                    text: app.files.length === 1
                        ? app.fileName(app.files[0])
                        : i18np("%1 file", "%1 files", app.files.length)
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: M3.classic ? M3.cornerCard : 28
            color: M3.surfaceContainerLow

            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width - 48
                spacing: 16
                visible: app.devices.length === 0

                MLoadingIndicator {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 48
                    implicitHeight: 48
                    running: QuickShare.discovering
                }
                MText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    role: "titleMedium"
                    color: M3.surfaceContent
                    text: QuickShare.available ? i18n("Looking for devices nearby…") : i18n("Quick Share is not running")
                }
                MText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    role: "bodyMedium"
                    color: M3.surfaceVariantContent
                    text: i18n("On the phone, pull down quick settings, open Quick Share and choose Everyone. Both devices need to be on the same Wi-Fi.")
                }
            }

            GridView {
                id: grid
                anchors.fill: parent
                anchors.margins: 12
                visible: app.devices.length > 0
                clip: true
                cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 136)))
                cellHeight: 168
                model: app.devices

                delegate: Item {
                    id: tile

                    required property var modelData
                    readonly property var transfer: app.transferFor(modelData.id)
                    readonly property bool busy: transfer !== null
                        && ["connecting", "waiting", "transferring"].includes(transfer.phase)
                    readonly property bool done: transfer !== null && transfer.phase === "finished"
                    readonly property bool failed: transfer !== null
                        && ["rejected", "cancelled", "failed"].includes(transfer.phase)

                    width: grid.cellWidth
                    height: grid.cellHeight

                    MStateLayer {
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: 20
                        hovered: area.containsMouse
                        pressed: area.pressed
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: 72
                            implicitHeight: 72

                            IconCircle {
                                anchors.centerIn: parent
                                size: 64
                                icon: tile.done ? "dialog-ok" : (tile.modelData.kind === "computer" ? "computer" : "phone")
                                containerColor: tile.done ? M3.primary : (tile.failed ? M3.errorContainer : M3.secondaryContainer)
                                contentColor: tile.done ? M3.primaryContent : (tile.failed ? M3.errorContainerContent : M3.secondaryContainerContent)
                            }
                            MCircularProgress {
                                anchors.fill: parent
                                visible: tile.busy
                                running: tile.busy
                            }
                        }
                        MText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            role: "labelLarge"
                            color: M3.surfaceContent
                            text: tile.modelData.name
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.Wrap
                        }
                        MText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            role: "bodySmall"
                            color: tile.failed ? M3.error : M3.surfaceVariantContent
                            text: app.status(tile.transfer)
                            visible: text.length > 0
                            wrapMode: Text.Wrap
                        }
                        Item {
                            Layout.fillHeight: true
                        }
                    }

                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: tile.busy ? QuickShare.cancel(tile.transfer.id) : app.sendTo(tile.modelData)
                    }
                    QQC2.ToolTip.visible: area.containsMouse && tile.busy
                    QQC2.ToolTip.text: i18n("Click to cancel")
                    QQC2.ToolTip.delay: 600
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            MText {
                Layout.fillWidth: true
                role: "bodySmall"
                color: M3.surfaceVariantContent
                wrapMode: Text.WordWrap
                text: i18n("Shown as %1", QuickShare.name)
                visible: QuickShare.name.length > 0
            }
            MButton {
                text: i18n("Done")
                variant: "tonal"
                onClicked: app.close()
            }
        }
    }
}
