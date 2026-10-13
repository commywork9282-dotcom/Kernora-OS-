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
    implicitHeight: 112
    activeFocusOnTab: true

    Accessible.role: Accessible.Button
    Accessible.name: name
    Accessible.description: summary
    Accessible.onPressAction: clicked()
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()

    scale: mouse.pressed ? 0.975 : 1
    Behavior on scale {
        NumberAnimation { duration: M3.durationShort4; easing.type: Easing.Bezier; easing.bezierCurve: M3.easingEmphasizedDecelerate }
    }

    StoreSurface {
        id: card
        anchors.fill: parent
        hovered: mouse.containsMouse
        pressed: mouse.pressed
        focused: root.activeFocus
        pressPoint: Qt.point(mouse.mouseX, mouse.mouseY)
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        AppIcon {
            Layout.alignment: Qt.AlignVCenter
            size: 64
            scale: mouse.containsMouse ? 1.06 : 1
            Behavior on scale {
                NumberAnimation { duration: M3.durationMedium2; easing.type: Easing.Bezier; easing.bezierCurve: M3.easingEmphasizedDecelerate }
            }
            name: root.iconSource
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                MText {
                    Layout.fillWidth: true
                    role: "titleMedium"
                    text: root.name
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
                StateChip {
                    installed: root.installed
                    busy: root.busy
                    hasUpdate: root.hasUpdate
                    progress: root.progress
                }
            }
            MText {
                Layout.fillWidth: true
                role: "bodyMedium"
                text: root.summary
                color: M3.surfaceVariantContent
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: 2
            }
            RowLayout {
                spacing: 6
                visible: root.rating > 0 || root.verified
                Stars {
                    value: root.rating
                }
                MIcon {
                    size: 14
                    visible: root.verified
                    source: "kernora-verified"
                    color: M3.primary
                }
            }
        }
    }

    LinearProgress {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 16
        anchors.bottomMargin: 8
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
