/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Templates as T
import org.kde.kirigami as Kirigami
import org.kde.desktop as Desktop
import "impl"

Desktop.ComboBox {
    id: control

    delegate: MenuItem {
        required property var model
        required property var modelData
        required property int index

        width: ListView.view.width
        height: implicitHeight
        text: control.textRole
            ? (Array.isArray(control.model) ? modelData[control.textRole] : model[control.textRole])
            : modelData
        highlighted: control.highlightedIndex === index
        checked: control.currentIndex === index
        hoverEnabled: control.hoverEnabled
    }

    MenuItem {
        id: probe
        visible: false
        text: "Ag"
    }

    popup: T.Popup {
        Kirigami.OverlayZStacking.layer: Kirigami.OverlayZStacking.Menu
        z: Kirigami.OverlayZStacking.z

        y: control.height + 4
        width: Math.max(control.width, 160)
        implicitHeight: contentItem.implicitHeight + topPadding + bottomPadding
        topPadding: 8
        bottomPadding: 8
        leftPadding: 0
        rightPadding: 0
        topMargin: Kirigami.Units.mediumSpacing
        bottomMargin: Kirigami.Units.mediumSpacing
        modal: true
        dim: true
        closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutside
        transformOrigin: Item.Top

        T.Overlay.modal: Item { }

        enter: Transition {
            ParallelAnimation {
                NumberAnimation {
                    property: "scale"
                    from: 0.92
                    to: 1
                    duration: M3.motionScale > 0 ? M3.durationMedium2 : 0
                    easing.type: Easing.Bezier
                    easing.bezierCurve: M3.easingEmphasizedDecelerate
                }
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: M3.motionScale > 0 ? M3.durationShort4 : 0
                }
            }
        }
        exit: Transition {
            NumberAnimation {
                property: "opacity"
                to: 0
                duration: M3.motionScale > 0 ? M3.durationShort3 : 0
            }
        }

        contentItem: ListView {
            readonly property bool hasCheckables: true
            readonly property bool hasIcons: false

            clip: height < implicitHeight
            implicitHeight: count * probe.implicitHeight
            model: control.delegateModel
            currentIndex: control.highlightedIndex
            highlightRangeMode: ListView.ApplyRange
            highlightMoveDuration: 0
            boundsBehavior: Flickable.StopAtBounds

            T.ScrollBar.vertical: Desktop.ScrollBar {}
        }

        background: Kirigami.ShadowedRectangle {
            radius: M3.cornerMenu
            color: M3.surfaceContainerHigh
            border.width: 1
            border.color: M3.withAlpha(M3.outlineVariant, 0.5)
            shadow.xOffset: 0
            shadow.yOffset: 3
            shadow.size: 14
            shadow.color: Qt.rgba(0, 0, 0, M3.dark ? 0.45 : 0.18)
        }
    }
}
