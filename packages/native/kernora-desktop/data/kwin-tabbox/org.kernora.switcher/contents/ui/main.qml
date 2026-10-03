/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-FileCopyrightText: 2020 Chris Holland <zrenfire@gmail.com>
    SPDX-FileCopyrightText: 2023 Nate Graham <nate@kde.org>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.kwin 3.0 as KWin
import org.kde.kirigami as Kirigami
import org.kernora.m3
import org.kernora.ui

KWin.TabBoxSwitcher {
    id: tabBox

    Instantiator {
        active: tabBox.visible
        delegate: PlasmaCore.Dialog {
            location: PlasmaCore.Types.Floating
            backgroundHints: PlasmaCore.Dialog.NoBackground
            visible: true
            flags: Qt.Popup | Qt.X11BypassWindowManagerHint
            x: tabBox.screenGeometry.x + tabBox.screenGeometry.width * 0.5 - dialogMainItem.width * 0.5
            y: tabBox.screenGeometry.y + tabBox.screenGeometry.height * 0.5 - dialogMainItem.height * 0.5

            mainItem: FocusScope {
                id: dialogMainItem
                focus: true

                readonly property int margin: 24
                readonly property int padding: 16

                property int maxWidth: tabBox.screenGeometry.width * 0.9 - margin * 2 - padding * 2
                property int maxHeight: tabBox.screenGeometry.height * 0.7 - margin * 2 - padding * 2
                property real screenFactor: tabBox.screenGeometry.width / tabBox.screenGeometry.height
                property int maxGridColumnsByWidth: Math.max(1, Math.floor(maxWidth / grid.cellWidth))

                property int gridColumns: {
                    const c = Math.max(1, Math.min(grid.count, maxGridColumnsByWidth));
                    const residue = grid.count % c;
                    if (residue == 0) {
                        return c;
                    }
                    return columnCountRecursion(c, c, c - residue);
                }
                property int gridRows: Math.ceil(grid.count / gridColumns)

                width: Math.min(Math.max(grid.cellWidth, grid.cellWidth * gridColumns), maxWidth) + (margin + padding) * 2
                height: Math.min(Math.max(grid.cellHeight, grid.cellHeight * gridRows), maxHeight) + (margin + padding) * 2

                function columnCountRecursion(prevC, prevBestC, prevDiff) {
                    const c = prevC - 1;
                    if (prevC * prevC <= grid.count + prevDiff
                            || maxHeight < Math.ceil(grid.count / c) * grid.cellHeight) {
                        return prevBestC;
                    }
                    const residue = grid.count % c;
                    if (residue == 0) {
                        return c;
                    }
                    const diff = c - residue;
                    if (diff < prevDiff) {
                        return columnCountRecursion(c, c, diff);
                    }
                    return columnCountRecursion(c, prevBestC, diff);
                }

                MultiEffect {
                    source: surface
                    anchors.fill: surface
                    shadowEnabled: true
                    shadowColor: "#000000"
                    shadowOpacity: 0.4
                    shadowBlur: 1.0
                    shadowVerticalOffset: 6
                    blurMax: 40
                }
                Rectangle {
                    id: surface
                    anchors.fill: parent
                    anchors.margins: dialogMainItem.margin
                    radius: M3.classic ? M3.cornerDialog : 36
                    color: M3.surfaceContainer
                }

                GridView {
                    id: grid
                    anchors.fill: surface
                    anchors.margins: dialogMainItem.padding
                    clip: true
                    focus: true
                    model: tabBox.model
                    currentIndex: tabBox.currentIndex
                    keyNavigationWraps: true
                    highlightMoveDuration: 0

                    readonly property int thumbnailWidth: 240
                    readonly property int thumbnailHeight: Math.round(thumbnailWidth / dialogMainItem.screenFactor)
                    cellWidth: thumbnailWidth + 24
                    cellHeight: thumbnailHeight + 72

                    delegate: MouseArea {
                        id: item
                        required property int index
                        required property var model
                        readonly property bool current: GridView.isCurrentItem

                        width: grid.cellWidth
                        height: grid.cellHeight
                        hoverEnabled: true
                        Accessible.name: model.caption
                        Accessible.role: Accessible.ListItem
                        onClicked: tabBox.model.activate(index)

                        Rectangle {
                            id: card
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: M3.classic ? M3.cornerCard : 28
                            color: item.current ? M3.surfaceContainerHighest
                                 : (item.containsMouse ? M3.surfaceContainerHigh : "transparent")
                            border.width: item.current ? 3 : 0
                            border.color: M3.primary
                            Behavior on color { ColorAnimation { duration: M3.durationShort3 } }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 10

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 4
                                    spacing: 10
                                    Kirigami.Icon {
                                        implicitWidth: 32
                                        implicitHeight: 32
                                        source: item.model.icon
                                    }
                                    MText {
                                        Layout.fillWidth: true
                                        role: "labelLarge"
                                        text: item.model.caption
                                        elide: Text.ElideRight
                                        color: item.current ? M3.surfaceContent : M3.surfaceVariantContent
                                    }
                                    Rectangle {
                                        implicitWidth: 28
                                        implicitHeight: 28
                                        radius: 14
                                        visible: item.model.closeable && typeof tabBox.model.close !== 'undefined'
                                                 && (item.containsMouse || item.current)
                                        color: closeMouse.containsMouse ? M3.secondaryContainer : "transparent"
                                        MIcon {
                                            anchors.centerIn: parent
                                            size: 18
                                            source: "window-close"
                                            color: M3.surfaceVariantContent
                                        }
                                        MouseArea {
                                            id: closeMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: tabBox.model.close(item.index)
                                        }
                                    }
                                }

                                RoundedClip {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: M3.classic ? M3.cornerImage : 18
                                    Rectangle {
                                        anchors.fill: parent
                                        color: M3.surfaceContainerLow
                                    }
                                    KWin.WindowThumbnail {
                                        anchors.fill: parent
                                        wId: item.model.windowId
                                    }
                                }
                            }
                        }
                    }

                    onCurrentIndexChanged: tabBox.currentIndex = grid.currentIndex
                }

                MText {
                    anchors.centerIn: surface
                    visible: grid.count === 0
                    role: "bodyLarge"
                    color: M3.surfaceVariantContent
                    text: i18ndc("kwin", "@info:placeholder no entries in the task switcher", "No open windows")
                }

                Keys.onPressed: event => {
                    if (event.key == Qt.Key_Left) {
                        grid.moveCurrentIndexLeft();
                    } else if (event.key == Qt.Key_Right) {
                        grid.moveCurrentIndexRight();
                    } else if (event.key == Qt.Key_Up) {
                        grid.moveCurrentIndexUp();
                    } else if (event.key == Qt.Key_Down) {
                        grid.moveCurrentIndexDown();
                    } else {
                        return;
                    }
                    grid.currentIndexChanged(grid.currentIndex);
                }
            }
        }
    }
}
