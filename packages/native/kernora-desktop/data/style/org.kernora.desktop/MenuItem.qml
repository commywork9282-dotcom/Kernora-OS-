/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
import org.kde.kirigami as Kirigami
import org.kde.desktop as Desktop
import "impl"

T.MenuItem {
    id: control

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding,
                             36)
    baselineOffset: contentItem.y + contentItem.baselineOffset

    height: visible ? undefined : 0

    readonly property int inset: 6
    readonly property bool listHasCheckables: (ListView.view && ListView.view.hasCheckables) || checkable
    readonly property bool listHasIcons: (ListView.view && ListView.view.hasIcons)
                                         || icon.name !== "" || icon.source.toString() !== ""
    readonly property color ink: highlighted || down ? M3.secondaryContainerContent : M3.surfaceContent

    leftPadding: inset + 12
    rightPadding: inset + 12
    topPadding: 6
    bottomPadding: 6
    spacing: 12
    hoverEnabled: !Kirigami.Settings.isMobile
    opacity: enabled ? 1 : M3.stateDisabledContent

    icon.width: Kirigami.Units.iconSizes.small
    icon.height: Kirigami.Units.iconSizes.small

    Kirigami.MnemonicData.enabled: enabled && visible
    Kirigami.MnemonicData.controlType: Kirigami.MnemonicData.MenuItem
    Kirigami.MnemonicData.label: text
    Shortcut {
        enabled: !(RegExp(/\&[^\&]/).test(control.text))
        sequence: control.Kirigami.MnemonicData.sequence
        onActivated: {
            if (control.checkable) {
                control.toggle();
            } else {
                control.clicked();
            }
        }
    }

    contentItem: RowLayout {
        spacing: control.spacing

        Kirigami.Icon {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: control.icon.width
            Layout.preferredHeight: control.icon.height
            visible: control.listHasCheckables
            source: "checkmark"
            color: control.ink
            opacity: control.checked ? 1 : 0
            animated: false
            Behavior on opacity {
                enabled: M3.motionScale > 0
                NumberAnimation { duration: M3.durationShort3 }
            }
        }

        Kirigami.Icon {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: control.icon.width
            Layout.preferredHeight: control.icon.height
            visible: control.listHasIcons
            source: control.icon.name !== "" ? control.icon.name : control.icon.source
            color: Qt.colorEqual(control.icon.color, "transparent") ? control.ink : control.icon.color
            animated: false
        }

        Desktop.Label {
            id: label

            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
            Layout.preferredWidth: Math.ceil(implicitWidth)
            text: control.Kirigami.MnemonicData.richTextLabel
            textFormat: Text.StyledText
            font: control.font
            color: control.ink
            elide: Text.ElideRight
            visible: control.text
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
        }

        Desktop.Label {
            id: shortcut

            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: 12
            visible: control.action && control.action.shortcut !== undefined && text.length > 0

            Shortcut {
                id: itemShortcut
                enabled: false
                sequence: (control.action && control.action.shortcut !== undefined) ? control.action.shortcut : ""
            }

            text: itemShortcut.nativeText
            font: control.font
            color: control.highlighted || control.down ? M3.secondaryContainerContent : M3.surfaceVariantContent
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
        }

        Item {
            Layout.preferredWidth: control.subMenu ? Kirigami.Units.iconSizes.small : 0
        }
    }

    arrow: Kirigami.Icon {
        x: control.mirrored ? control.leftPadding : control.width - width - control.rightPadding
        y: control.topPadding + (control.availableHeight - height) / 2
        width: Kirigami.Units.iconSizes.small
        height: width
        source: control.mirrored ? "arrow-left" : "arrow-right"
        color: control.ink
        visible: control.subMenu
        animated: false
    }

    indicator: Item {}

    background: Item {
        implicitWidth: 160
        implicitHeight: 36

        Rectangle {
            id: pill

            anchors.fill: parent
            anchors.leftMargin: M3.classic ? 0 : control.inset
            anchors.rightMargin: M3.classic ? 0 : control.inset
            radius: M3.classic ? 0 : 8
            color: control.highlighted || control.down ? M3.secondaryContainer : M3.withAlpha(M3.secondaryContainer, 0)

            Behavior on color {
                enabled: M3.motionScale > 0
                ColorAnimation {
                    duration: M3.durationShort3
                    easing.type: Easing.Bezier
                    easing.bezierCurve: M3.easingStandard
                }
            }

            MStateLayer {
                radius: pill.radius
                color: M3.secondaryContainerContent
                hovered: false
                pressed: control.down
                pressPoint: Qt.point(control.pressX - pill.x, control.pressY - pill.y)
            }
        }
    }
}
