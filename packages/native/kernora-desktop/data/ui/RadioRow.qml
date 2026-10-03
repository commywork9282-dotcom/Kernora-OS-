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
    property string subtitle
    property string appIcon
    property bool checked: false
    signal clicked()

    implicitWidth: 320
    implicitHeight: subtitle.length > 0 ? 64 : 52
    activeFocusOnTab: true

    Accessible.role: Accessible.RadioButton
    Accessible.name: title
    Accessible.checked: checked
    Accessible.onPressAction: clicked()
    Keys.onSpacePressed: clicked()
    Keys.onReturnPressed: clicked()

    Rectangle {
        anchors.fill: parent
        radius: M3.classic ? M3.cornerListItem : 16
        color: root.checked ? M3.secondaryContainer : "transparent"
        Behavior on color { ColorAnimation { duration: M3.durationShort4 } }
        MStateLayer {
            radius: M3.classic ? M3.cornerListItem : 16
            color: M3.surfaceContent
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
        spacing: 12
        QQC2.RadioButton {
            checked: root.checked
            focusPolicy: Qt.NoFocus
            onClicked: root.clicked()
            Accessible.ignored: true
        }
        AppIcon {
            visible: root.appIcon.length > 0
            size: 32
            name: root.appIcon
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            MText {
                Layout.fillWidth: true
                role: "bodyLarge"
                text: root.title
                color: root.checked ? M3.secondaryContainerContent : M3.surfaceContent
            }
            MText {
                Layout.fillWidth: true
                role: "bodySmall"
                text: root.subtitle
                visible: text.length > 0
                color: M3.surfaceVariantContent
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
