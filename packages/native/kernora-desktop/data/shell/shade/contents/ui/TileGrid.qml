/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import QtQml.Models
import "m3"

Item {
    id: grid

    required property var tiles
    required property var names
    property bool editing: false

    readonly property var defaultLayout: [
        ["internet", 2], ["bluetooth", 2], ["sound", 2], ["dark", 2], ["dnd", 2], ["night", 2],
        ["quickshare", 2], ["mic", 1], ["airplane", 1], ["awake", 1], ["screenshot", 1]
    ]
    readonly property real gap: 8
    readonly property real cell: (width - gap * 3) / 4
    readonly property real tileHeight: M3.classic ? 100 : 64
    readonly property var hidden: {
        const shown = [];
        for (let i = 0; i < layout.count; ++i) {
            shown.push(layout.get(i).tileId);
        }
        return Object.keys(grid.tiles).filter(id => !shown.includes(id));
    }

    implicitHeight: flow.implicitHeight + (editing ? spare.implicitHeight + 16 : 0)

    Settings {
        id: store
        location: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/kernora-quicksettingsrc"
        category: "Tiles"
        property string layout: ""
    }

    ListModel {
        id: layout
    }

    function load(): void {
        const rows = [];
        const seen = [];
        for (const entry of String(store.layout).split(",")) {
            const [id, span] = entry.split(":");
            if (grid.tiles[id] !== undefined && !seen.includes(id)) {
                seen.push(id);
                rows.push([id, span === "1" ? 1 : 2]);
            }
        }
        layout.clear();
        for (const [id, span] of (rows.length > 0 ? rows : grid.defaultLayout)) {
            if (grid.tiles[id] !== undefined) {
                layout.append({ tileId: id, span: span });
            }
        }
    }

    function save(): void {
        const entries = [];
        for (let i = 0; i < visual.items.count; ++i) {
            const item = visual.items.get(i).model;
            entries.push(item.tileId + ":" + item.span);
        }
        store.layout = entries.join(",");
        store.sync();
        load();
    }

    function reset(): void {
        store.layout = "";
        store.sync();
        load();
    }

    Component.onCompleted: load()

    DelegateModel {
        id: visual
        model: layout

        delegate: DropArea {
            id: slot

            required property int index
            required property string tileId
            required property int span
            readonly property int visualIndex: DelegateModel.itemsIndex

            width: M3.classic || span === 1 ? grid.cell : grid.cell * 2 + grid.gap
            height: grid.tileHeight

            onEntered: drag => {
                const from = drag.source.visualIndex;
                if (from !== slot.visualIndex) {
                    visual.items.move(from, slot.visualIndex);
                }
            }

            Item {
                id: content

                readonly property int visualIndex: slot.visualIndex
                width: slot.width
                height: slot.height
                anchors.horizontalCenter: slot.horizontalCenter
                anchors.verticalCenter: slot.verticalCenter

                Drag.active: dragger.active
                Drag.source: content
                Drag.hotSpot.x: width / 2
                Drag.hotSpot.y: height / 2

                states: State {
                    when: dragger.active
                    ParentChange { target: content; parent: grid }
                    AnchorChanges {
                        target: content
                        anchors.horizontalCenter: undefined
                        anchors.verticalCenter: undefined
                    }
                    PropertyChanges { content.z: 10; content.scale: 1.05 }
                }

                Loader {
                    id: tile
                    anchors.fill: parent
                    sourceComponent: grid.tiles[slot.tileId]
                    enabled: !grid.editing
                    onLoaded: item.compact = Qt.binding(() => slot.span === 1)
                }

                MouseArea {
                    anchors.fill: parent
                    visible: grid.editing
                    cursorShape: dragger.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    onClicked: {
                        if (!M3.classic) {
                            layout.setProperty(slot.index, "span", slot.span === 1 ? 2 : 1);
                            grid.save();
                        }
                    }
                }

                DragHandler {
                    id: dragger
                    enabled: grid.editing
                    onActiveChanged: if (!active) grid.save()
                }

                Rectangle {
                    visible: grid.editing
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: -6
                    width: 24
                    height: 24
                    radius: 12
                    color: M3.inverseSurface

                    MIcon {
                        anchors.centerIn: parent
                        size: 16
                        source: "list-remove"
                        color: M3.inverseOnSurface
                    }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            visual.items.remove(slot.visualIndex);
                            grid.save();
                        }
                    }
                }
            }
        }
    }

    Flow {
        id: flow
        width: parent.width
        spacing: grid.gap

        move: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: M3.durationMedium2
                easing.type: Easing.Bezier
                easing.bezierCurve: M3.easingEmphasizedDecelerate
            }
        }

        Repeater {
            model: visual
        }
    }

    Column {
        id: spare
        visible: grid.editing
        anchors.top: flow.bottom
        anchors.topMargin: 16
        width: parent.width
        spacing: 8

        MText {
            role: "labelLarge"
            color: M3.surfaceVariantContent
            text: grid.hidden.length > 0 ? i18n("Tap a tile to add it") : i18n("All tiles are in use")
        }

        Flow {
            width: parent.width
            spacing: 8

            Repeater {
                model: grid.hidden

                delegate: Rectangle {
                    id: chip
                    required property string modelData
                    width: chipRow.implicitWidth + 24
                    height: 40
                    radius: 20
                    color: M3.surfaceContainerHighest

                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 8
                        MIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            size: 18
                            source: "list-add"
                            color: M3.primary
                        }
                        MText {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "labelLarge"
                            text: grid.names[chip.modelData] || chip.modelData
                        }
                    }
                    MStateLayer {
                        radius: chip.radius
                        color: M3.surfaceContent
                        hovered: chipMouse.containsMouse
                        pressed: chipMouse.pressed
                        pressPoint: Qt.point(chipMouse.mouseX, chipMouse.mouseY)
                    }
                    MouseArea {
                        id: chipMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            layout.append({ tileId: chip.modelData, span: 1 });
                            grid.save();
                        }
                    }
                }
            }
        }
    }
}
