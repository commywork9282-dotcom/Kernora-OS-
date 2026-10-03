/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Templates as T
import org.kde.kirigami as Kirigami
import "private" as P

T.Button {
    id: control

    Kirigami.Theme.colorSet: Kirigami.Theme.Button
    Kirigami.Theme.inherit: false

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)
    baselineOffset: contentItem.y + contentItem.baselineOffset

    readonly property bool iconOnly: display === T.AbstractButton.IconOnly || text.length === 0

    topPadding: 6
    bottomPadding: 6
    leftPadding: iconOnly ? 9 : 18
    rightPadding: iconOnly ? 9 : 18
    spacing: 8

    icon.width: Kirigami.Units.iconSizes.small
    icon.height: Kirigami.Units.iconSizes.small

    hoverEnabled: Qt.styleHints.useHoverEffects

    Kirigami.MnemonicData.enabled: enabled && visible
    Kirigami.MnemonicData.controlType: Kirigami.MnemonicData.ActionElement
    Kirigami.MnemonicData.label: display !== T.AbstractButton.IconOnly ? text : ""
    Shortcut {
        enabled: !(RegExp(/\&[^\&]/).test(control.text))
        sequence: control.Kirigami.MnemonicData.sequence
        onActivated: control.animateClick()
    }

    contentItem: P.ButtonContent {
        control: control
        color: surface.contentColor
        iconBesideText: false
    }

    background: P.ButtonSurface {
        id: surface
        control: control
        implicitWidth: control.iconOnly ? 36 : 64
        implicitHeight: 36
        variant: control.highlighted || (control.checkable && control.checked)
            ? "filled"
            : control.flat ? "text" : "tonal"
    }
}
