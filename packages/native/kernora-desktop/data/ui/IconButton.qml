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
    background: Rectangle {
        radius: !M3.classic && (root.pressed || root.checked) ? Math.round(height * 0.3) : height / 2
        color: root.checked ? M3.secondaryContainer : "transparent"
        Behavior on color { ColorAnimation { duration: M3.durationShort4 } }
        Behavior on radius {
            enabled: !M3.classic
            NumberAnimation {
                duration: root.pressed ? M3.durationShort3 : M3.durationMedium2
                easing.type: Easing.Bezier
                easing.bezierCurve: M3.easingEmphasizedDecelerate
            }
        }

        MStateLayer {
            radius: parent.radius
            color: root.checked ? M3.secondaryContainerContent : root.ink
            hovered: root.hovered
            pressed: root.pressed
            focused: root.visualFocus
        }
        MIcon {
            anchors.centerIn: parent
            size: 24
            source: root.iconName
            color: root.checked ? M3.secondaryContainerContent : root.ink
        }
    }
}
