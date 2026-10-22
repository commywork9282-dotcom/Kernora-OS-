/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Templates as T
import org.kde.kirigami as Kirigami

T.Popup {
    id: root

    property var items: []

    function openAt(item: Item, x: real, y: real): void {
        const point = item.mapToItem(parent, x, y);
        root.x = Math.min(point.x, parent.width - implicitWidth - 8);
        root.y = Math.min(point.y, parent.height - implicitHeight - 8);
        open();
    }

    padding: 0
    topPadding: 12
    bottomPadding: 12
    readonly property real widestRow: {
        let widest = 0;
        for (const row of list.children) {
            widest = Math.max(widest, row.implicitWidth || 0);
        }
        return widest;
    }

    implicitWidth: Math.max(200, widestRow)
    implicitHeight: list.implicitHeight + topPadding + bottomPadding
    modal: false
    focus: true
    closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutside

    background: Kirigami.ShadowedRectangle {
        radius: M3.cornerMenu
        color: M3.surfaceContainerHigh
        border.width: M3.classic ? 0 : 1
        border.color: M3.withAlpha(M3.outlineVariant, 0.5)
        readonly property var shadowSpec: M3.elevationOf("menu")
        shadow.xOffset: 0
        shadow.yOffset: M3.classic ? shadowSpec.offset : 3
        shadow.size: M3.classic ? shadowSpec.blur : 14
        shadow.color: Qt.rgba(0, 0, 0, M3.classic ? shadowSpec.opacity : M3.dark ? 0.45 : 0.18)
    }

    enter: Transition {
        NumberAnimation {
            property: "scale"
            from: 0.85
            to: 1
            duration: M3.durationMedium2
            easing.type: Easing.Bezier
            easing.bezierCurve: M3.easingEmphasizedDecelerate
        }
        NumberAnimation {
            property: "opacity"
            from: 0
            to: 1
            duration: M3.durationShort4
        }
    }
    exit: Transition {
        NumberAnimation {
            property: "opacity"
            to: 0
            duration: M3.durationShort3
            easing.type: Easing.Bezier
            easing.bezierCurve: M3.easingEmphasizedAccelerate
        }
    }
    transformOrigin: T.Popup.TopLeft

    contentItem: Column {
        id: list

        Repeater {
            model: root.items

            delegate: Item {
                id: row

                required property var modelData

                width: root.width
                implicitWidth: 6 + 12 + 18 + 12 + label.implicitWidth + 24 + 6
                height: 36

                Rectangle {
                    id: pill
                    anchors.fill: parent
                    anchors.leftMargin: M3.classic ? 0 : 6
                    anchors.rightMargin: M3.classic ? 0 : 6
                    radius: M3.classic ? 0 : 12
                    color: mouse.containsMouse ? M3.secondaryContainer : M3.withAlpha(M3.secondaryContainer, 0)

                    Behavior on color {
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
                        pressed: mouse.pressed
                        pressPoint: Qt.point(mouse.mouseX - pill.x, mouse.mouseY)
                    }
                }

                MIcon {
                    id: glyph
                    x: 6 + 12
                    anchors.verticalCenter: parent.verticalCenter
                    size: 18
                    source: row.modelData.icon
                    color: mouse.containsMouse ? M3.secondaryContainerContent : M3.surfaceVariantContent
                }
                MText {
                    id: label
                    anchors.left: glyph.right
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    role: "bodyMedium"
                    text: row.modelData.text
                    color: mouse.containsMouse ? M3.secondaryContainerContent : M3.surfaceContent
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        root.close();
                        row.modelData.action();
                    }
                }
            }
        }
    }
}
