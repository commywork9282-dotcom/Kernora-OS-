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

    property string title
    property string subtitle
    property url preview
    property bool selected: false
    property url scene
    property bool addTile: false
    signal clicked()

    implicitWidth: 180
    implicitHeight: thumb.height + 44
    activeFocusOnTab: true
    Accessible.role: Accessible.RadioButton
    Accessible.name: title
    Accessible.checked: selected
    Keys.onSpacePressed: clicked()
    Keys.onReturnPressed: clicked()

    RoundedClip {
        id: thumb
        width: parent.width
        height: Math.round(width * 0.62)
        radius: M3.classic ? M3.cornerImage : 18 + 10 * selectMorph.value
        MMorph {
            id: selectMorph
            active: root.selected
            dampingRatio: M3.springExpressiveDefaultDamping
            response: M3.springExpressiveDefaultResponse
        }

        Rectangle {
            anchors.fill: parent
            color: M3.surfaceContainerHigh
        }

        Image {
            anchors.fill: parent
            visible: root.preview.toString().length > 0
            source: root.preview
            sourceSize: Qt.size(360, 224)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        Loader {
            active: root.scene.toString().length > 0
            width: 960
            height: 600
            scale: thumb.width / 960
            transformOrigin: Item.TopLeft
            source: root.scene
            onLoaded: {
                item.intro = 1;
                item.phase = 0.3;
            }
        }

        MIcon {
            anchors.centerIn: parent
            visible: root.addTile && root.preview.toString().length === 0
            size: 32
            source: "list-add"
            color: M3.surfaceVariantContent
        }

        MStateLayer {
            radius: thumb.radius
            hovered: mouse.containsMouse
            pressed: mouse.pressed
            focused: root.activeFocus
            pressPoint: Qt.point(mouse.mouseX, mouse.mouseY)
        }

        Rectangle {
            anchors.fill: parent
            radius: thumb.radius
            color: "transparent"
            border.width: root.selected ? 3 : 0
            border.color: M3.primary
        }
        Rectangle {
            visible: root.selected
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 10
            width: 28
            height: 28
            radius: 14
            color: M3.primary
            MIcon {
                anchors.centerIn: parent
                size: 20
                source: "checkmark"
                color: M3.primaryContent
            }
        }
    }

    ColumnLayout {
        anchors.top: thumb.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 4
        spacing: 0
        MText {
            Layout.fillWidth: true
            role: "labelLarge"
            text: root.title
        }
        MText {
            Layout.fillWidth: true
            role: "bodySmall"
            text: root.subtitle
            visible: text.length > 0
            color: M3.surfaceVariantContent
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
