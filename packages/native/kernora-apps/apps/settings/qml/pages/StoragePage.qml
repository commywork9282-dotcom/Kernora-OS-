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
import org.kde.notification
import "../components"

SettingsPage {
    id: page

    title: i18n("Storage")

    property var volumes: SystemInfo.storage()
    property real trash: Files.trashSize()

    Repeater {
        model: page.volumes

        delegate: Rectangle {
            id: volume
            required property var modelData
            readonly property real used: Math.max(0, modelData.total - modelData.free)
            readonly property real share: modelData.total > 0 ? used / modelData.total : 0

            width: parent.width
            implicitHeight: content.implicitHeight + 40
            radius: M3.classic ? M3.cornerCard : 28
            color: M3.surfaceContainer

            ColumnLayout {
                id: content
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 20
                spacing: 14

                RowLayout {
                    spacing: 16
                    IconCircle {
                        icon: volume.modelData.system ? "drive-harddisk-root" : "drive-harddisk"
                        accent: 1
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        MText {
                            Layout.fillWidth: true
                            role: "titleMedium"
                            text: volume.modelData.system ? i18n("This computer") : (volume.modelData.name || volume.modelData.mountPoint)
                        }
                        MText {
                            Layout.fillWidth: true
                            role: "bodyMedium"
                            color: M3.surfaceVariantContent
                            text: i18n("%1 free of %2", SystemInfo.formatBytes(volume.modelData.free), SystemInfo.formatBytes(volume.modelData.total))
                        }
                    }
                    MText {
                        role: "titleLarge"
                        text: i18n("%1%", Math.round(volume.share * 100))
                        color: volume.share > 0.9 ? M3.error : M3.primary
                    }
                }
                LinearProgress {
                    Layout.fillWidth: true
                    wavy: false
                    thickness: 8
                    value: volume.share
                }
            }
        }
    }

    Group {
        title: i18n("Trash")

        ListItem {
            title: i18n("Trash")
            subtitle: page.trash > 0 ? i18n("Takes %1", SystemInfo.formatBytes(page.trash)) : i18nc("the trash has nothing in it", "Empty")
            icon: page.trash > 0 ? "user-trash-full" : "user-trash"
            accent: 1
            trailing: Component {
                QQC2.Button {
                    text: i18n("Empty")
                    enabled: page.trash > 0
                    onClicked: emptyDialog.open()
                }
            }
            onClicked: Process.openUrl("trash:/")
        }
        ListItem {
            title: i18n("Open Files")
            icon: "system-file-manager"
            iconStyle: "plain"
            chevron: true
            onClicked: Process.launchApplication("org.kernora.files.desktop", [])
        }
    }

    Dialog {
        id: emptyDialog
        icon: "user-trash"
        title: i18n("Empty the trash?")
        text: i18n("Everything in the trash is deleted for good.")
        acceptText: i18n("Empty")
        destructive: true
        onAccepted: Files.emptyTrash((ok, message) => {
            page.trash = Files.trashSize();
            page.volumes = SystemInfo.storage();
            if (ok) {
                trashEmptied.sendEvent();
            } else {
                page.notify(message);
            }
        })
    }

    Notification {
        id: trashEmptied
        componentName: "plasma_workspace"
        eventId: "Trash: emptied"
        title: i18n("Trash emptied")
        iconName: "user-trash"
    }
}
