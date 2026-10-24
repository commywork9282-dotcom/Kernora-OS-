/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kernora.system
import "m3"

ColumnLayout {
    id: panel

    required property QtObject backend
    signal back()
    signal requestClose()

    spacing: 12

    readonly property bool on: QuickShare.enabled
    readonly property string mode: QuickShare.visibility
    readonly property bool everyoneForAWhile: mode === "temporary"

    function remaining(seconds: int): string {
        return seconds > 60 ? i18n("%1 min", Math.ceil(seconds / 60)) : i18n("%1 sec", Math.max(1, seconds));
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        MIconButton {
            icon: "go-previous"
            text: i18n("Back")
            onClicked: panel.back()
        }
        MText {
            Layout.fillWidth: true
            role: "titleLarge"
            text: i18n("Quick Share")
            elide: Text.ElideRight
        }
        MIconButton {
            icon: "configure"
            text: i18n("Quick Share settings")
            onClicked: {
                panel.backend.openSettings("quickshare");
                panel.requestClose();
            }
        }
    }

    PanelGroup {
        Layout.fillWidth: true

        Item {
            width: parent.width
            implicitHeight: 56

            MText {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                role: "titleSmall"
                text: panel.on ? i18n("On") : i18n("Off")
            }
            MSwitch {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                enabled: QuickShare.available
                checked: panel.on
                text: i18n("Quick Share")
                onToggled: QuickShare.setEnabled(!panel.on)
            }
        }
    }

    PanelGroup {
        Layout.fillWidth: true
        opacity: panel.on ? 1 : 0.5
        enabled: panel.on

        PanelRow {
            width: parent.width
            icon: "network-workgroup"
            title: i18n("Everyone")
            subtitle: i18n("Any device nearby can share with you")
            trailingIcon: panel.mode === "everyone" ? "dialog-positive" : ""
            onClicked: QuickShare.setVisibility("everyone")
        }
        PanelRow {
            width: parent.width
            icon: "view-hidden"
            title: i18n("Hidden")
            subtitle: i18n("No one can share with you")
            trailingIcon: panel.mode !== "everyone" ? "dialog-positive" : ""
            onClicked: QuickShare.setVisibility("hidden")
        }

        Rectangle {
            width: parent.width - 32
            x: 16
            height: 1
            color: M3.outlineVariant
            visible: panel.mode !== "everyone"
        }

        Item {
            width: parent.width
            implicitHeight: 64
            visible: panel.mode !== "everyone"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 12

                Item {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    Rectangle {
                        anchors.fill: parent
                        radius: panel.everyoneForAWhile ? 12 : 18
                        color: panel.everyoneForAWhile ? M3.primary : M3.withAlpha(M3.surfaceContent, 0.08)
                        Behavior on radius { NumberAnimation { duration: M3.durationMedium2 } }
                    }
                    MIcon {
                        anchors.centerIn: parent
                        size: 20
                        source: "kernora-timer"
                        color: panel.everyoneForAWhile ? M3.primaryContent : M3.surfaceContent
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    MText {
                        Layout.fillWidth: true
                        role: "titleSmall"
                        text: i18n("Visible to everyone")
                        elide: Text.ElideRight
                    }
                    MText {
                        Layout.fillWidth: true
                        role: "bodySmall"
                        color: M3.surfaceVariantContent
                        text: panel.everyoneForAWhile ? i18n("%1 left", panel.remaining(QuickShare.visibleFor)) : i18n("For 10 min")
                        elide: Text.ElideRight
                    }
                }
                MSwitch {
                    checked: panel.everyoneForAWhile
                    text: i18n("Visible to everyone")
                    onToggled: QuickShare.setHighVisibility(!panel.everyoneForAWhile)
                }
            }
        }
    }

    MText {
        Layout.fillWidth: true
        Layout.leftMargin: 8
        Layout.rightMargin: 8
        role: "bodySmall"
        color: M3.surfaceVariantContent
        wrapMode: Text.Wrap
        text: i18n("Visible as %1. Make sure both devices are unlocked, close together and on the same Wi-Fi.", QuickShare.name)
        visible: panel.on && QuickShare.name.length > 0
    }
}
