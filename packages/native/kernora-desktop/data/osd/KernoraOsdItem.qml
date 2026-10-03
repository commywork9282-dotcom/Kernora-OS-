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

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: M3.surfaceContainerHighest
                }
                Rectangle {
                    id: fill
                    height: parent.height
                    radius: height / 2
                    color: root.overdriven ? M3.error : M3.primary
                    width: Math.max(height, springWidth.value)
                    readonly property real goal: track.width * root.fraction
                    property bool shown: false
                    onGoalChanged: {
                        if (shown) {
                            springWidth.animateTo(goal);
                        } else if (track.width > 0) {
                            springWidth.jumpTo(goal);
                            shown = true;
                        }
                    }
                    MSpring {
                        id: springWidth
                        response: M3.springSpatialFastResponse
                        dampingRatio: M3.springSpatialFastDamping
                    }
                    Behavior on color { ColorAnimation { duration: M3.durationShort4 } }
                }
                MIcon {
                    x: (fill.height - size) / 2
                    anchors.verticalCenter: parent.verticalCenter
                    size: 24
                    source: root.icon
                    color: root.overdriven ? M3.errorContent : M3.primaryContent
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    color: fill.width > track.width - width - 24
                        ? (root.overdriven ? M3.errorContent : M3.primaryContent) : M3.surfaceContent
                    text: root.formatPercent(Math.round(Number(root.osdValue)))
                    font: M3.labelLarge
                    renderType: Text.QtRendering
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
