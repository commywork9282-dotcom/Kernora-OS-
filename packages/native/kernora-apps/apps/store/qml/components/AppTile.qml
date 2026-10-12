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
    property string iconSource
    property bool installed
    property bool busy
    property bool hasUpdate
    property int progress: -1
    property real rating: 0

    signal clicked()

    implicitWidth: 176
    implicitHeight: 232
    activeFocusOnTab: true

    Accessible.role: Accessible.Button
    Accessible.name: name
    Accessible.description: summary
    Accessible.onPressAction: clicked()
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()

    Rectangle {
        id: card
        anchors.fill: parent
        radius: M3.classic ? M3.cornerCard : 24
        color: M3.surfaceContainerLow

        MStateLayer {
            radius: card.radius
            color: M3.surfaceContent
            hovered: mouse.containsMouse
            pressed: mouse.pressed
            focused: root.activeFocus
            pressPoint: Qt.point(mouse.mouseX, mouse.mouseY)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 6

        AppIcon {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            Layout.bottomMargin: 6
            size: 80
            name: root.iconSource
            scale: mouse.containsMouse ? 1.05 : 1
            Behavior on scale {
                NumberAnimation { duration: M3.durationMedium2; easing.type: Easing.Bezier; easing.bezierCurve: M3.easingEmphasizedDecelerate }
            }
        }
        MText {
            Layout.fillWidth: true
            role: "titleSmall"
            text: root.name
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            maximumLineCount: 1
        }
        MText {
            Layout.fillWidth: true
            Layout.fillHeight: true
            role: "bodySmall"
            text: root.summary
            color: M3.surfaceVariantContent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignTop
            wrapMode: Text.Wrap
            elide: Text.ElideRight
            maximumLineCount: 2
        }
        Item {
            Layout.fillWidth: true
            implicitHeight: 24

            StateChip {
                anchors.centerIn: parent
                installed: root.installed
                busy: root.busy
                hasUpdate: root.hasUpdate
                progress: root.progress
            }
            Stars {
                anchors.centerIn: parent
                visible: !root.installed && !root.busy && value > 0
                value: root.rating
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
