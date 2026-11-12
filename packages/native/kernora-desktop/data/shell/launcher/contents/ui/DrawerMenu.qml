/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Templates as T
import org.kde.kirigami as Kirigami
import "m3"

T.Popup {
    id: root

    property var groups: []
    property point anchorTop: Qt.point(0, 0)
    property point anchorBottom: Qt.point(0, 0)

    readonly property real roomAbove: anchorTop.y - 16
    readonly property real roomBelow: (parent ? parent.height : 0) - anchorBottom.y - 16
    readonly property bool arrowDown: implicitHeight <= roomAbove || (implicitHeight > roomBelow && roomAbove >= roomBelow)
    readonly property bool fits: arrowDown ? implicitHeight <= roomAbove : implicitHeight <= roomBelow
    readonly property real arrowX: anchorTop.x - x
    readonly property color container: M3.dark ? M3.surfaceBright : M3.surfaceContainerLow

    function openFor(anchor: Item, iconTop: real, iconHeight: real): void {
        anchorTop = anchor.mapToItem(parent, anchor.width / 2, iconTop);
        anchorBottom = anchor.mapToItem(parent, anchor.width / 2, iconTop + iconHeight);
        open();
    }

    x: parent ? Math.max(8, Math.min(parent.width - implicitWidth - 8, anchorTop.x - 28)) : 0
    y: {
        const wanted = arrowDown ? anchorTop.y - implicitHeight - 8 : anchorBottom.y + 8;
        return parent ? Math.max(8, Math.min(parent.height - implicitHeight - 8, wanted)) : wanted;
    }

    padding: 0
    modal: false
    focus: true
    closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutside

    readonly property real widestRow: {
        let widest = 0;
        for (const group of column.children) {
            for (const row of (group.rows ? group.rows.children : [])) {
                widest = Math.max(widest, row.implicitWidth || 0);
            }
        }
        return widest;
    }

    implicitWidth: Math.max(200, widestRow)
    implicitHeight: column.implicitHeight

    background: Item {}

    enter: Transition {
        NumberAnimation {
            property: "scale"
            from: 0.9
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
    transformOrigin: root.arrowDown ? Item.Bottom : Item.Top

    contentItem: Column {
        id: column
        spacing: 4

        Repeater {
            model: root.groups

            delegate: Item {
                id: group

                required property var modelData
                required property int index
                readonly property alias rows: rowColumn
                readonly property bool arrowHere: root.arrowDown ? index === root.groups.length - 1 : index === 0

                width: root.width
                height: rowColumn.implicitHeight + 16

                Kirigami.ShadowedRectangle {
                    anchors.fill: parent
                    radius: 24
                    color: root.container
                    shadow.size: 16
                    shadow.yOffset: 4
                    shadow.color: Qt.rgba(0, 0, 0, M3.dark ? 0.4 : 0.16)
                }

                Rectangle {
                    visible: group.arrowHere && root.fits
                    width: 14
                    height: 14
                    rotation: 45
                    color: root.container
                    x: Math.max(20, Math.min(group.width - 34, root.arrowX - 7))
                    y: root.arrowDown ? group.height - 9 : -5
                    antialiasing: true
                }

                Column {
                    id: rowColumn
                    y: 8
                    width: parent.width

                    Repeater {
                        model: group.modelData

                        delegate: Item {
                            id: row

                            required property var modelData

                            width: root.width
                            implicitWidth: 16 + 20 + 16 + label.implicitWidth + 28
                            height: 44

                            Rectangle {
                                id: pill
                                anchors.fill: parent
                                anchors.leftMargin: 6
                                anchors.rightMargin: 6
                                radius: 14
                                color: "transparent"

                                MStateLayer {
                                    radius: pill.radius
                                    color: M3.surfaceContent
                                    hovered: mouse.containsMouse
                                    pressed: mouse.pressed
                                    pressPoint: Qt.point(mouse.mouseX - pill.x, mouse.mouseY)
                                }
                            }

                            Item {
                                id: glyph
                                x: 16
                                anchors.verticalCenter: parent.verticalCenter
                                width: 20
                                height: 20

                                MIcon {
                                    anchors.centerIn: parent
                                    visible: !row.modelData.colorful
                                    size: 20
                                    source: row.modelData.icon || "open_in_new"
                                    color: M3.surfaceContent
                                }
                                Kirigami.Icon {
                                    anchors.fill: parent
                                    visible: !!row.modelData.colorful
                                    source: row.modelData.icon || ""
                                    animated: false
                                }
                            }
                            MText {
                                id: label
                                anchors.left: glyph.right
                                anchors.leftMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                role: "bodyLarge"
                                text: row.modelData.text
                                color: M3.surfaceContent
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
        }
    }
}
