/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kwindowsystem
import org.kernora.m3

Item {
    id: cell

    property string plugin
    property string name
    property string description
    property string kind
    property var span: [2, 2]
    property real cellWidth: 144
    property real cellHeight: 100
    property bool showAdd: false

    signal tapped()
    signal addRequested()
    signal dragStarted()
    signal dragFinished()

    readonly property real previewScale: 0.6
    readonly property bool clock: kind.indexOf("clock") >= 0
    readonly property real cardWidth: Math.round((span[0] * cellWidth - 16) * previewScale)
    readonly property real cardHeight: Math.round((span[1] * cellHeight - 16) * previewScale)

    width: Math.max(cardWidth, 176)
    height: column.implicitHeight

    Column {
        id: column

        width: parent.width
        spacing: 0

        Item {
            width: parent.width
            height: cell.cardHeight + 16

            Rectangle {
                id: card

                anchors.horizontalCenter: parent.horizontalCenter
                y: 8
                width: cell.cardWidth
                height: cell.cardHeight
                radius: 28 * cell.previewScale
                color: cell.clock || cell.kind === "glance" || cell.kind === "weather" || cell.kind === "photo"
                    ? "transparent" : M3.surfaceContainer
                clip: true

                WidgetPreview {
                    anchors.fill: parent
                    kind: cell.kind
                    scale: cell.clock ? 1 : Math.min(1, cell.cardHeight / 150, cell.cardWidth / 170)
                }
            }

            TapHandler {
                onTapped: cell.tapped()
            }

            Item {
                id: dragSource

                anchors.fill: parent

                Drag.dragType: Drag.Automatic
                Drag.supportedActions: Qt.MoveAction | Qt.LinkAction
                Drag.mimeData: {
                    "text/x-plasmoidservicename": cell.plugin
                }
                Drag.onDragStarted: KWindowSystem.showingDesktop = true
                Drag.onDragFinished: dropAction => {
                    dragSource.Drag.active = false;
                    cell.dragFinished();
                }

                DragHandler {
                    id: dragHandler
                    target: null
                    onActiveChanged: {
                        if (!active) {
                            return;
                        }
                        card.grabToImage(result => {
                            if (!dragHandler.active) {
                                return;
                            }
                            dragSource.Drag.imageSource = result.url;
                            cell.dragStarted();
                            dragSource.Drag.active = true;
                        }, Qt.size(Math.round(card.width), Math.round(card.height)));
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: Math.max(texts.implicitHeight, 48)

            Column {
                id: texts

                width: parent.width
                visible: !cell.showAdd

                MText {
                    width: parent.width
                    role: "titleSmall"
                    horizontalAlignment: Text.AlignHCenter
                    text: cell.name
                    color: M3.surfaceContent
                }
                MText {
                    width: parent.width
                    role: "bodyMedium"
                    horizontalAlignment: Text.AlignHCenter
                    text: i18ndc("kernora-ui", "widget size in cells, width by height", "%1 × %2", cell.span[0], cell.span[1])
                    color: M3.surfaceVariantContent
                }
                MText {
                    width: parent.width
                    visible: text.length > 0
                    role: "bodySmall"
                    horizontalAlignment: Text.AlignHCenter
                    text: cell.description
                    color: M3.surfaceVariantContent
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    lineHeightMode: Text.FixedHeight
                    lineHeight: 16
                }
            }

            Rectangle {
                id: addButton

                anchors.horizontalCenter: parent.horizontalCenter
                y: 4
                visible: cell.showAdd
                width: addRow.implicitWidth + 8 + 16
                height: 40
                radius: height / 2
                color: M3.primary

                MStateLayer {
                    radius: addButton.radius
                    color: M3.primaryContent
                    hovered: addMouse.containsMouse
                    pressed: addMouse.pressed
                    pressPoint: Qt.point(addMouse.mouseX, addMouse.mouseY)
                }

                Row {
                    id: addRow

                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    MIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        size: 19
                        source: "list-add"
                        color: M3.primaryContent
                    }
                    MText {
                        anchors.verticalCenter: parent.verticalCenter
                        role: "labelLarge"
                        text: i18nd("kernora-ui", "Add")
                        color: M3.primaryContent
                    }
                }

                MouseArea {
                    id: addMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: cell.addRequested()
                }

                Accessible.role: Accessible.Button
                Accessible.name: i18nd("kernora-ui", "Add %1 widget", cell.name)
            }
        }
    }
}
