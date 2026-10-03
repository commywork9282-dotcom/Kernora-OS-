/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
import org.kde.kirigami as Kirigami
import org.kde.desktop as Desktop
import "../impl"

Item {
    id: content

    property T.AbstractButton control
    property color color: M3.surfaceContent
    property bool iconBesideText: true

    readonly property bool hasIcon: control.icon.name.length > 0 || control.icon.source.toString().length > 0
    readonly property bool showText: control.text.length > 0 && control.display !== T.AbstractButton.IconOnly
    readonly property bool showIcon: hasIcon && control.display !== T.AbstractButton.TextOnly
                                     && (iconBesideText || !showText || control.display === T.AbstractButton.TextUnderIcon)
    readonly property bool menuArrow: control.Accessible.role === Accessible.ButtonMenu && showText
    readonly property bool stacked: control.display === T.AbstractButton.TextUnderIcon

    implicitWidth: Math.ceil(grid.implicitWidth)
    implicitHeight: grid.implicitHeight
    baselineOffset: label.visible ? grid.y + label.y + label.baselineOffset : 0

    GridLayout {
        id: grid

        anchors.centerIn: parent
        width: Math.min(implicitWidth, content.width)
        columns: content.stacked ? 1 : 3
        rowSpacing: 2
        columnSpacing: content.control.spacing

        Kirigami.Icon {
            Layout.alignment: Qt.AlignCenter
            Layout.preferredWidth: content.control.icon.width
            Layout.preferredHeight: content.control.icon.height
            visible: content.showIcon
            source: content.control.icon.name.length > 0 ? content.control.icon.name : content.control.icon.source
            color: Qt.colorEqual(content.control.icon.color, "transparent") ? content.color : content.control.icon.color
            animated: false
        }

        Desktop.Label {
            id: label

            Layout.alignment: Qt.AlignCenter
            Layout.fillWidth: true
            Layout.preferredWidth: Math.ceil(implicitWidth)
            Layout.maximumWidth: Math.ceil(implicitWidth)
            visible: content.showText
            text: content.control.Kirigami.MnemonicData.richTextLabel
            textFormat: Text.StyledText
            font: M3.classic
                ? Qt.font({ family: content.control.font.family,
                            pointSize: content.control.font.pointSize > 0 ? content.control.font.pointSize : 10,
                            weight: Font.Medium, letterSpacing: M3.buttonTracking,
                            capitalization: Font.AllUppercase })
                : content.control.font
            color: content.color
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Kirigami.Icon {
            Layout.alignment: Qt.AlignCenter
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            visible: content.menuArrow && !content.stacked
            source: "arrow-down"
            color: content.color
            animated: false
        }
    }
}
