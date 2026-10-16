/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kernora.m3
import org.kernora.ui

Item {
    id: root

    property string appId
    property string name
    property string summary
    property string developer
    property string iconSource
    property bool installed
    property bool busy
    property bool hasUpdate
    property bool verified
    property int progress: -1
    property real rating: 0

    signal clicked()

    implicitWidth: 360
    implicitHeight: 88
    activeFocusOnTab: true

    Accessible.role: Accessible.Button
    Accessible.name: name
    Accessible.description: summary
    Accessible.onPressAction: clicked()
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()

    MStateLayer {
        radius: M3.classic ? M3.cornerCard : 16
        color: M3.surfaceContent
        hovered: mouse.containsMouse
        pressed: mouse.pressed
        focused: root.activeFocus
        pressPoint: Qt.point(mouse.mouseX, mouse.mouseY)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 12
        spacing: 16

        AppPlate {
            Layout.alignment: Qt.AlignVCenter
            size: 64
            iconName: root.iconSource
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            MText {
                Layout.fillWidth: true
                role: "titleMedium"
                text: root.name
                elide: Text.ElideRight
                maximumLineCount: 1
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                MText {
                    Layout.maximumWidth: parent.width - (root.verified ? 18 : 0)
                    role: "bodyMedium"
                    text: root.developer.length > 0 ? root.developer : root.summary
                    color: M3.surfaceVariantContent
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
                MIcon {
                    size: 14
                    visible: root.verified
                    source: "kernora-verified"
                    color: M3.primary
                }
                Item { Layout.fillWidth: true }
            }
            Item {
                Layout.fillWidth: true
                implicitHeight: 20

                MText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    visible: root.busy || root.installed || root.hasUpdate
                    role: "bodySmall"
                    elide: Text.ElideRight
                    color: root.hasUpdate && !root.busy ? M3.primary : M3.surfaceVariantContent
                    text: root.busy ? (root.progress >= 0 ? i18n("%1%", root.progress) : i18n("Working…"))
                        : root.hasUpdate ? i18n("Update available") : i18n("Installed")
                }
                RatingLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !root.busy && !root.installed && !root.hasUpdate && value > 0
                    value: root.rating
                }
            }
        }
    }

    LinearProgress {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 88
        anchors.rightMargin: 12
        anchors.bottomMargin: 3
        visible: root.busy
        indeterminate: root.progress < 0
        value: Math.max(0, root.progress) / 100
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
