/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import org.kernora.m3

QQC2.AbstractButton {
    id: root

    property string iconName
    property color ink: M3.surfaceVariantContent
    property color checkedFill: M3.secondaryContainer
    property color checkedInk: M3.secondaryContainerContent

    implicitWidth: 40
    implicitHeight: 40
    focusPolicy: Qt.TabFocus
    hoverEnabled: true
    opacity: enabled ? 1 : 0.38

    Accessible.role: checkable ? Accessible.CheckBox : Accessible.Button
    Accessible.name: text
    QQC2.ToolTip.text: text
    QQC2.ToolTip.visible: hovered && text.length > 0
    QQC2.ToolTip.delay: 600

    contentItem: Item {}
    MMorph { id: pressMorph; active: root.pressed }
    MMorph { id: checkMorph; active: root.checked }

    background: Rectangle {
        readonly property real rest: height / 2 + (Math.round(height * 0.3) - height / 2) * checkMorph.value
        radius: M3.classic ? height / 2 : Math.max(0, rest + (Math.round(height * 0.22) - rest) * pressMorph.value)
        color: root.checked ? root.checkedFill : "transparent"
        Behavior on color { ColorAnimation { duration: M3.durationShort4 } }

        MStateLayer {
            radius: parent.radius
            color: root.checked ? root.checkedInk : root.ink
            hovered: root.hovered
            pressed: root.pressed
            focused: root.visualFocus
        }
        MIcon {
            anchors.centerIn: parent
            size: 24
            source: root.iconName
            color: root.checked ? root.checkedInk : root.ink
        }
    }
}
