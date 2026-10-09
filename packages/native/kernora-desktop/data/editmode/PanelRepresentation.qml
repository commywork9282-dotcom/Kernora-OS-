/*
    SPDX-FileCopyrightText: KDE Plasma Developers
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.components as PC3
import org.kde.plasma.core as PlasmaCore
import org.kde.ksvg as KSvg
import org.kde.plasma.shell.panel as Panel
import org.kde.kirigami as Kirigami
import org.kernora.m3

Item {
    id: root

    property string text
    property int alignment: Qt.AlignHCenter | Qt.AlignBottom
    property string tooltip

    property bool isVertical: false
    property bool checked: false
    property bool windowVisible: false
    property bool panelVisible: true
    property bool translucentPanel: false
    property bool sunkenPanel: false
    property bool adaptivePanel: false
    property bool fillAvailable: false
    property int floatingGap: 0
    property int windowZ: 0
    property var mainIconSource: null
    property int screenHeight: Math.round(screenRect.height / 2)

    readonly property bool iconAndLabelsShouldlookSelected: checked || mouseArea.pressed

    signal clicked()

    implicitHeight: mainItem.height
    implicitWidth: mainItem.width

    PC3.ToolTip {
        text: root.tooltip
        visible: mouseArea.containsMouse && text.length > 0
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -8
        radius: M3.classic ? M3.cornerCard : 20
        color: root.iconAndLabelsShouldlookSelected ? M3.secondaryContainer
            : M3.withAlpha(M3.surfaceContent, mouseArea.containsMouse ? M3.stateHover : 0)

        Behavior on color {
            ColorAnimation {
                duration: M3.durationShort4
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }

    ColumnLayout {
        id: mainItem
        spacing: Kirigami.Units.smallSpacing
        Rectangle {
            id: screenRect

            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Math.round(Math.min(Kirigami.Units.gridUnit * 6, Screen.width * 0.1))
            implicitHeight: Math.round(Math.min(Kirigami.Units.gridUnit * 4, Screen.width * 0.1))
            color: M3.surfaceContainerHighest
            border.width: 0
            radius: M3.classic ? M3.cornerCardInner : 14
            clip: root.sunkenPanel

            RowLayout {
                anchors.fill: parent
                Rectangle {
                    id: panelImage

                    implicitWidth: root.isVertical ? Math.round(parent.width / 6) : Math.round(parent.width * (root.fillAvailable ? 1 : 0.8))
                    implicitHeight: root.isVertical ? Math.round(parent.height * (root.fillAvailable ? 1 : 0.8)) : Math.round(parent.height / 4)
                    Layout.alignment: root.alignment
                    Layout.bottomMargin: root.sunkenPanel * -Math.round(height / 2) + root.floatingGap
                    color: root.translucentPanel ? M3.withAlpha(M3.primary, 0.45) : M3.primary
                    border.color: "transparent"
                    visible: root.panelVisible
                    clip: root.adaptivePanel
                    radius: M3.classic ? 3 : Math.min(width, height) / 2

                    z: 1

                    Loader {
                        id: horizontalAdaptivePanelLoader
                        active: root.adaptivePanel && !root.isVertical
                        sourceComponent: Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: Math.round(panelImage.width / 3)
                            color: M3.surfaceContainerHighest
                            border.color: M3.primary
                            width: panelImage.width
                            height: Math.round(panelImage.height * 4)
                            radius: Math.round(height / 2)
                            rotation: 45
                        }
                    }

                    Loader {
                        id: verticalAdaptivePanelLoader
                        active: root.adaptivePanel && root.isVertical
                        sourceComponent: Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: Math.round(panelImage.height / 4)
                            color: M3.surfaceContainerHighest
                            border.color: M3.primary
                            width: Math.round(panelImage.width * 2)
                            height: panelImage.height
                            radius: Math.round(height / 2)
                            rotation: 45
                        }
                    }

                    Rectangle {
                        id: panelBorder
                        anchors.fill: parent
                        color: "transparent"
                        border.color: M3.primary
                        radius: panelImage.radius
                    }
                }
            }

            Rectangle {
                id: window
                width: Math.round(parent.width / 2)
                height: Math.round(parent.height / 2)
                visible: root.windowVisible
                radius: 6
                color: M3.tertiaryContainer
                border.color: "transparent"

                x: root.isVertical ? Math.round(panelImage.x + panelImage.width / 2) : Math.round(screenRect.width / 2 - width / 2) + Kirigami.Units.gridUnit
                y: root.isVertical ? Math.round(screenRect.height / 2 - height / 2) : Math.round(panelImage.y - height + panelImage.height / 2)
                z: root.windowZ

                Row {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.smallSpacing
                    Repeater {
                        model: 3
                        delegate: Rectangle {
                            width: Math.round(Kirigami.Units.gridUnit / 6)
                            height: width
                            radius: Math.round(height / 2)
                            color: M3.tertiaryContainerContent
                        }
                    }
                }
            }

            Kirigami.Icon {
                id: mainIcon
                visible: valid
                anchors.centerIn: parent
                transform: Translate {
                    y: root.isVertical ? 0 : Math.round((mainIcon.y - panelImage.y) / 4)
                    x: root.isVertical ? Math.round((mainIcon.x - panelImage.x) / 4) : 0
                }
                height: parent.height / 2
                width: height
                source: root.mainIconSource
                isMask: true
                color: root.iconAndLabelsShouldlookSelected ? M3.secondaryContainerContent : M3.surfaceVariantContent
            }
        }
    }
}
