/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Templates as T
import org.kde.kirigami as Kirigami
import "private" as P

T.ToolButton {
    id: control

    Kirigami.Theme.colorSet: flat ? Kirigami.Theme.Window : Kirigami.Theme.Button
    Kirigami.Theme.inherit: flat

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)
    baselineOffset: contentItem.y + contentItem.baselineOffset

    readonly property bool iconOnly: display === T.AbstractButton.IconOnly || text.length === 0

    flat: true
    padding: 7
    leftPadding: iconOnly ? 7 : 12
    rightPadding: iconOnly ? 7 : 14
    spacing: 8

    icon.width: Kirigami.Units.iconSizes.smallMedium
    icon.height: Kirigami.Units.iconSizes.smallMedium

    hoverEnabled: Qt.styleHints.useHoverEffects

    Kirigami.MnemonicData.enabled: enabled && visible
    Kirigami.MnemonicData.controlType: Kirigami.MnemonicData.SecondaryControl
    Kirigami.MnemonicData.label: text
    Shortcut {
        enabled: !(RegExp(/\&[^\&]/).test(control.text))
        sequence: control.Kirigami.MnemonicData.sequence
        onActivated: control.animateClick()
    }

    contentItem: P.ButtonContent {
        control: control
        color: surface.variant === "standard" && control.enabled ? Kirigami.Theme.textColor : surface.contentColor
    }

    background: P.ButtonSurface {
        id: surface
        control: control
        implicitWidth: 36
        implicitHeight: 36
        variant: {
            if (control.checkable && control.checked) {
                return control.flat ? "tonal" : "filled";
            }
            if (control.highlighted) {
                return "tonal";
            }
            return control.flat ? "standard" : "tonal";
        }
    }
}
