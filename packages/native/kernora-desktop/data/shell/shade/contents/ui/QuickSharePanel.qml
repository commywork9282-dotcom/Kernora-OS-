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

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 104
        radius: 28
        color: panel.on ? M3.primaryContainer : M3.surfaceContainerHighest
        Behavior on color { ColorAnimation { duration: M3.durationMedium2 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 16

            Item {
                Layout.preferredWidth: 72
                Layout.preferredHeight: 72

                MShape {
                    anchors.fill: parent
                    shape: M3.classic ? "circle" : "cookie9"
                    color: panel.on ? M3.primary : M3.withAlpha(M3.surfaceContent, 0.1)
                    RotationAnimator on rotation {
                        from: 0
                        to: 360
                        duration: 24000
                        loops: Animation.Infinite
                        running: panel.on && panel.visible && M3.motionScale > 0 && !M3.classic
                    }
                }
                MIcon {
                    anchors.centerIn: parent
                    size: 34
                    source: "kernora-quickshare"
                    color: panel.on ? M3.primaryContent : M3.surfaceContent
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                MText {
                    Layout.fillWidth: true
                    role: "titleMedium"
                    color: panel.on ? M3.primaryContainerContent : M3.surfaceContent
                    text: !panel.on ? i18n("Off") : panel.mode === "hidden" ? i18n("On, hidden") : i18n("Ready to receive")
                    elide: Text.ElideRight
                }
                MText {
                    Layout.fillWidth: true
                    role: "bodySmall"
                    color: panel.on ? M3.primaryContainerContent : M3.surfaceVariantContent
                    opacity: 0.85
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    text: panel.on ? i18n("You'll appear as %1", QuickShare.name) : i18n("Nobody nearby can see this computer")
                }
            }
            MSwitch {
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
            icon: "kernora-everyone"
            title: i18n("Everyone")
            subtitle: i18n("Any device nearby can share with you")
            active: panel.mode === "everyone"
            onClicked: QuickShare.setVisibility("everyone")
        }
        PanelRow {
            width: parent.width
            icon: "kernora-timer"
            title: i18n("Everyone for 10 minutes")
            subtitle: panel.mode === "temporary" ? i18n("%1 left", panel.remaining(QuickShare.visibleFor)) : i18n("Then you're hidden again")
            active: panel.mode === "temporary"
            onClicked: QuickShare.setVisibility("temporary")
        }
        PanelRow {
            width: parent.width
            icon: "view-hidden"
            title: i18n("Hidden")
            subtitle: i18n("No one can share with you")
            active: panel.mode === "hidden"
            onClicked: QuickShare.setVisibility("hidden")
        }
    }

    PanelGroup {
        Layout.fillWidth: true

        PanelRow {
            width: parent.width
            icon: "kernora-upload"
            title: i18n("Send and receive")
            subtitle: i18n("Open Quick Share")
            trailingIcon: "go-next"
            onClicked: {
                panel.backend.openQuickShare();
                panel.requestClose();
            }
        }
    }
}
