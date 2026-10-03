/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami

Kirigami.Icon {
    id: root

    property int size: 24

    implicitWidth: size
    implicitHeight: size
    roundToIconSize: false
    isMask: true
    animated: false
    color: M3.surfaceVariantContent

    Behavior on color {
        ColorAnimation {
            duration: M3.durationMedium1
            easing.type: Easing.Bezier
            easing.bezierCurve: M3.easingStandard
        }
    }
}
