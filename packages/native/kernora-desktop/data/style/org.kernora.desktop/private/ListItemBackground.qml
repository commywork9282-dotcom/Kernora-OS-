/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Templates as T
import org.kde.kirigami as Kirigami
import "../impl"

Item {
    id: background

    property T.ItemDelegate control

    readonly property bool highlight: control.highlighted || control.down
    readonly property bool useAlternatingColors: {
        if (control.TableView.view?.alternatingRows && row % 2) {
            return true;
        } else if (control.Kirigami.Theme.useAlternateBackgroundColor && index % 2) {
            return true;
        }
        return false;
    }
    readonly property bool hasInset: control.leftInset > 0 || control.rightInset > 0
                                     || control.topInset > 0 || control.bottomInset > 0
    readonly property bool reallyFocus: control.visualFocus
                                        || (control.activeFocus && control.focusReason === Qt.OtherFocusReason)

    function updateItem(): void {
    }

    Rectangle {
        anchors.fill: parent
        visible: background.useAlternatingColors
        color: Kirigami.Theme.alternateBackgroundColor
    }

    Rectangle {
        id: row

        anchors {
            fill: parent
            leftMargin: background.control.leftInset
            rightMargin: background.control.rightInset
            topMargin: background.control.topInset
            bottomMargin: background.control.bottomInset
        }
        radius: background.hasInset ? (M3.classic ? M3.cornerListItem : 8) : 0
        color: background.highlight ? Kirigami.Theme.highlightColor : M3.withAlpha(Kirigami.Theme.highlightColor, 0)

        Behavior on color {
            enabled: M3.motionScale > 0
            ColorAnimation {
                duration: M3.durationShort4
                easing.type: Easing.Bezier
                easing.bezierCurve: M3.easingStandard
            }
        }

        MStateLayer {
            radius: row.radius
            color: background.highlight ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
            visible: background.control.enabled
            hovered: background.control.hovered
            pressed: background.control.down
            focused: background.reallyFocus
            pressPoint: Qt.point(background.control.pressX - row.x, background.control.pressY - row.y)
        }
    }
}
