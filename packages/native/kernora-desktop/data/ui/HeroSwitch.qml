/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kernora.m3

Item {
    id: root

    property string title
    property bool checked: false
    signal toggled(bool checked)

    width: parent ? parent.width : implicitWidth
    implicitWidth: 360
    implicitHeight: 72
    activeFocusOnTab: true

    Accessible.role: Accessible.CheckBox
    Accessible.name: title
    Accessible.checkable: true
    Accessible.checked: checked
    Accessible.onToggleAction: toggled(!checked)
    Keys.onSpacePressed: toggled(!checked)
    Keys.onReturnPressed: toggled(!checked)

    Rectangle {
        id: pill
        anchors.fill: parent
        radius: M3.classic ? M3.cornerCard : height / 2
        color: root.checked ? M3.primaryContainer : M3.surfaceContainerHigh
        Behavior on color {
            ColorAnimation { duration: M3.durationMedium1; easing.type: Easing.Bezier; easing.bezierCurve: M3.easingStandard }
        }
        MStateLayer {
            radius: pill.radius
            color: root.checked ? M3.primaryContainerContent : M3.surfaceContent
            hovered: mouse.containsMouse
            pressed: mouse.pressed
            focused: root.activeFocus
            pressPoint: Qt.point(mouse.mouseX, mouse.mouseY)
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 28
        anchors.rightMargin: 20
        MText {
            Layout.fillWidth: true
            role: "titleMedium"
            text: root.title
            color: root.checked ? M3.primaryContainerContent : M3.surfaceContent
        }
        QQC2.Switch {
            checked: root.checked
            focusPolicy: Qt.NoFocus
            onToggled: root.toggled(checked)
            Accessible.ignored: true
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.rightMargin: 84
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
