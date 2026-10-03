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

    Rectangle {
        id: pill
        anchors.fill: parent
        radius: M3.radius("indicator", height)
        color: root.current ? M3.secondaryContainer : M3.withAlpha(M3.secondaryContainer, 0)
        Behavior on color {
            ColorAnimation { duration: M3.durationShort4; easing.type: Easing.Bezier; easing.bezierCurve: M3.easingStandard }
        }
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
                role: "bodyLarge"
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
