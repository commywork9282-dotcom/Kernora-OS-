/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kernora.m3
import org.kernora.store

Item {
    id: page

    readonly property var app: QQC2.ApplicationWindow.window
    readonly property real contentWidth: Math.min(width - 48, 1200)
    readonly property int columns: Math.max(1, Math.min(3, Math.floor((contentWidth + 16) / 320)))

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: grid.implicitHeight + 64
        boundsBehavior: Flickable.StopAtBounds

        GridLayout {
            id: grid
            x: (flick.width - page.contentWidth) / 2
            y: 24
            width: page.contentWidth
            columns: page.columns
            columnSpacing: 16
            rowSpacing: 4

            Repeater {
                model: Store.categories

                delegate: Item {
                    id: row

                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.name
                    Accessible.onPressAction: page.app.openCategory(modelData.id)
                    Keys.onReturnPressed: page.app.openCategory(modelData.id)
                    Keys.onSpacePressed: page.app.openCategory(modelData.id)

                    MStateLayer {
                        radius: M3.classic ? M3.cornerCard : 12
                        color: M3.surfaceContent
                        hovered: mouse.containsMouse
                        pressed: mouse.pressed
                        focused: row.activeFocus
                        pressPoint: Qt.point(mouse.mouseX, mouse.mouseY)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 12
                        spacing: 20

                        MIcon {
                            size: 24
                            source: row.modelData.icon
                            color: M3.surfaceVariantContent
                        }
                        MText {
                            Layout.fillWidth: true
                            role: "bodyLarge"
                            text: row.modelData.name
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.app.openCategory(row.modelData.id)
                    }
                }
            }
        }
    }

    MScrollIndicator {
        flickable: flick
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
    }
}
