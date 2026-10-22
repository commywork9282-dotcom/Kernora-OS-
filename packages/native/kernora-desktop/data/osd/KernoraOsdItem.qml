/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import org.kernora.m3

Item {
    id: root

    property int timeout: 1800
    property var osdValue
    property int osdMaxValue: 100
    property string osdAdditionalText: ""
    property string icon
    property bool showingProgress: false

    readonly property real fraction: showingProgress ? Math.max(0, Math.min(1, Number(osdValue) / Math.max(1, osdMaxValue))) : 0
    readonly property bool overdriven: showingProgress && Number(osdValue) > 100

    function formatPercent(number) {
        return i18ndc("plasma_lookandfeel_org.kde.lookandfeel", "Percentage value", "%1%", number);
    }

    readonly property int margin: 18

    implicitWidth: surface.width + margin * 2
    implicitHeight: surface.height + margin * 2
    width: implicitWidth
    height: implicitHeight

    MultiEffect {
        source: surface
        anchors.fill: surface
        shadowEnabled: true
        shadowColor: "#000000"
        shadowOpacity: 0.35
        shadowBlur: 0.8
        shadowVerticalOffset: 4
        blurMax: 32
    }

    Rectangle {
        id: surface
        x: root.margin
        y: root.margin
        width: root.showingProgress ? 360 : Math.min(message.implicitWidth + 32, Screen.desktopAvailableWidth / 2)
        height: root.showingProgress ? (root.osdAdditionalText.length > 0 ? 96 : 64) : 56
        radius: height / 2 > 32 ? 32 : height / 2
        color: M3.surfaceContainerHigh

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4
            visible: root.showingProgress

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.topMargin: 4
                visible: root.osdAdditionalText.length > 0
                text: root.osdAdditionalText
                color: M3.surfaceVariantContent
                font: M3.labelLarge
                elide: Text.ElideRight
                renderType: Text.QtRendering
            }

            Item {
                id: track
                Layout.fillWidth: true
                Layout.fillHeight: true

                readonly property real level: Math.max(0, Math.min(1, levelSpring.value))
                readonly property color fill: root.overdriven ? M3.error : M3.primary
                readonly property color ink: root.overdriven ? M3.errorContent : M3.primaryContent
                property bool shown: false

                function settle(): void {
                    if (shown) {
                        levelSpring.animateTo(root.fraction);
                    } else if (width > 0) {
                        levelSpring.jumpTo(root.fraction);
                        shown = true;
                    }
                }

                Connections {
                    target: root
                    function onFractionChanged() { track.settle(); }
                }
                onWidthChanged: if (!shown) settle()

                MSpring {
                    id: levelSpring
                    response: M3.springSpatialFastResponse
                    dampingRatio: M3.springSpatialFastDamping
                }

                Item {
                    anchors.fill: parent
                    visible: M3.classic

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: M3.surfaceContainerHighest
                    }
                    Rectangle {
                        id: fill
                        height: parent.height
                        radius: height / 2
                        color: track.fill
                        width: Math.max(height, track.level * parent.width)
                        Behavior on color { ColorAnimation { duration: M3.durationShort4 } }
                    }
                    MIcon {
                        x: (fill.height - size) / 2
                        anchors.verticalCenter: parent.verticalCenter
                        size: 24
                        source: root.icon
                        color: track.ink
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        color: fill.width > parent.width - width - 24 ? track.ink : M3.surfaceContent
                        text: root.formatPercent(Math.round(Number(root.osdValue)))
                        font: M3.labelLarge
                        renderType: Text.QtRendering
                    }
                }

                Item {
                    id: expressive
                    anchors.fill: parent
                    visible: !M3.classic

                    readonly property real gap: 6
                    readonly property real slot: 4
                    readonly property real outer: height / 2
                    readonly property real handleX: track.level * (width - slot)
                    readonly property real activeWidth: Math.max(0, handleX - gap)
                    readonly property real inactiveX: handleX + slot + gap
                    readonly property real inactiveWidth: Math.max(0, width - inactiveX)
                    readonly property bool iconOnActive: activeWidth >= 48
                    readonly property bool valueOnInactive: inactiveWidth >= percent.implicitWidth + 40

                    Rectangle {
                        width: expressive.activeWidth
                        height: parent.height
                        visible: width > 0.5
                        color: track.fill
                        topLeftRadius: Math.min(expressive.outer, width / 2)
                        bottomLeftRadius: Math.min(expressive.outer, width / 2)
                        topRightRadius: Math.min(4, width / 2)
                        bottomRightRadius: Math.min(4, width / 2)
                        Behavior on color { ColorAnimation { duration: M3.durationShort4 } }
                    }
                    Rectangle {
                        x: expressive.inactiveX
                        width: expressive.inactiveWidth
                        height: parent.height
                        visible: width > 0.5
                        color: M3.secondaryContainer
                        topLeftRadius: Math.min(4, width / 2)
                        bottomLeftRadius: Math.min(4, width / 2)
                        topRightRadius: Math.min(expressive.outer, width / 2)
                        bottomRightRadius: Math.min(expressive.outer, width / 2)

                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            anchors.rightMargin: expressive.outer - 3
                            color: track.fill
                            visible: parent.width > expressive.outer * 2 && !expressive.valueOnInactive
                        }
                    }
                    Rectangle {
                        x: expressive.handleX
                        y: -4
                        width: expressive.slot
                        height: parent.height + 8
                        radius: width / 2
                        color: track.fill
                    }
                    MIcon {
                        x: expressive.iconOnActive ? 16 : expressive.inactiveX + 16
                        anchors.verticalCenter: parent.verticalCenter
                        size: 24
                        source: root.icon
                        color: expressive.iconOnActive ? track.ink : M3.secondaryContainerContent
                        visible: expressive.iconOnActive || expressive.inactiveWidth >= 48
                    }
                    Text {
                        id: percent
                        anchors.verticalCenter: parent.verticalCenter
                        x: expressive.valueOnInactive ? parent.width - width - 18
                                                      : Math.max(0, expressive.activeWidth - width - 14)
                        color: expressive.valueOnInactive ? M3.secondaryContainerContent : track.ink
                        text: root.formatPercent(Math.round(Number(root.osdValue)))
                        font: M3.labelLarge
                        renderType: Text.QtRendering
                        visible: expressive.valueOnInactive || expressive.activeWidth >= width + 24 + (expressive.iconOnActive ? 40 : 0)
                    }
                }
            }
        }

        RowLayout {
            id: message
            anchors.centerIn: parent
            spacing: 12
            visible: !root.showingProgress
            Rectangle {
                implicitWidth: 40
                implicitHeight: 40
                radius: 20
                color: M3.secondaryContainer
                visible: root.icon.length > 0
                MIcon {
                    anchors.centerIn: parent
                    size: 22
                    source: root.icon
                    color: M3.secondaryContainerContent
                }
            }
            Text {
                Layout.rightMargin: 8
                text: (root.showingProgress ? "" : root.osdValue) ?? ""
                color: M3.surfaceContent
                font: M3.titleMedium
                elide: Text.ElideRight
                renderType: Text.QtRendering
            }
        }
    }
}
