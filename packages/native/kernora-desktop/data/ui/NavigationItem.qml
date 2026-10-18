/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kernora.m3

Item {
    id: root

    property string title
    property string subtitle
    property string icon
    property int accent: -1
    property bool current: false
    property Component leading
    signal clicked()

    width: parent ? parent.width : implicitWidth
    implicitWidth: 300
    implicitHeight: subtitle.length > 0 ? 68 : 56
    activeFocusOnTab: true

    Accessible.role: Accessible.PageTab
    Accessible.name: title
    Accessible.description: subtitle
    Accessible.selected: current
    Accessible.onPressAction: clicked()
    Keys.onSpacePressed: clicked()
    Keys.onReturnPressed: clicked()

    MMorph {
        id: selectMorph
        active: root.current
        dampingRatio: M3.springExpressiveDefaultDamping
        response: M3.springExpressiveDefaultResponse
    }

    Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        width: M3.classic ? parent.width : Math.max(0, Math.min(parent.width, height + (parent.width - height) * selectMorph.value))
        radius: M3.radius("indicator", height)
        color: M3.secondaryContainer
        opacity: M3.classic ? (root.current ? 1 : 0) : Math.max(0, Math.min(1, selectMorph.value * 2.5))
        Behavior on opacity {
            enabled: M3.classic
            NumberAnimation { duration: M3.durationShort4; easing.type: Easing.Bezier; easing.bezierCurve: M3.easingStandard }
        }
    }

    Rectangle {
        id: pill
        anchors.fill: parent
        radius: M3.radius("indicator", height)
        color: "transparent"
        MStateLayer {
            radius: pill.radius
            color: root.current ? M3.secondaryContainerContent : M3.surfaceContent
            hovered: mouse.containsMouse
            pressed: mouse.pressed
            focused: root.activeFocus
            pressPoint: Qt.point(mouse.mouseX, mouse.mouseY)
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 16
        spacing: 14

        Loader {
            active: root.leading !== null || root.icon.length > 0
            visible: active
            sourceComponent: root.leading !== null ? root.leading : iconComponent
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            MText {
                Layout.fillWidth: true
                role: root.current ? "bodyLargeEmphasized" : "bodyLarge"
                text: root.title
                color: root.current ? M3.secondaryContainerContent : M3.surfaceContent
            }
            MText {
                Layout.fillWidth: true
                role: "bodySmall"
                text: root.subtitle
                visible: text.length > 0
                color: root.current ? M3.secondaryContainerContent : M3.surfaceVariantContent
                opacity: root.current ? 0.8 : 1
            }
        }
    }

    Component {
        id: iconComponent
        IconCircle {
            size: 36
            icon: root.icon
            accent: root.accent
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
