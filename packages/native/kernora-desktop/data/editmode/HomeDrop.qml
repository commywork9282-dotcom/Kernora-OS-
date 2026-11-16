/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kernora.m3
import "GridReorder.js" as GridReorder

Item {
    id: drop

    property Item layout: null
    property color accent: "white"
    property bool reorder: true

    readonly property real cellWidth: layout && layout.cellWidth > 0 ? layout.cellWidth : 1
    readonly property real cellHeight: layout && layout.cellHeight > 0 ? layout.cellHeight : 1
    readonly property int columns: layout ? Math.max(1, Math.floor(layout.width / cellWidth + 0.001)) : 1
    readonly property int rows: layout ? Math.max(1, Math.floor(layout.height / cellHeight + 0.001)) : 1
    readonly property real magnitude: 7
    readonly property bool motion: M3.motionScale > 0

    property bool active: false
    property var span: [1, 1]
    property var items: []
    property var origin: ({})
    property var shown: ({})
    property var target: null
    property point center: Qt.point(-1, -1)
    property var shakes: ({})
    property var moves: ({})
    property var settling: []
    property var outlines: [null, null, null, null]
    property var outlineOn: [false, false, false, false]
    property int outlineCurrent: 0

    parent: layout
    x: 0
    y: 0
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    z: -1

    function context(): var {
        return { columns: drop.columns, rows: drop.rows, cellWidth: drop.cellWidth, cellHeight: drop.cellHeight,
                 state: drop.origin };
    }

    function cellsOf(item: Item): var {
        return {
            x: Math.round(item.x / drop.cellWidth),
            y: Math.round(item.y / drop.cellHeight),
            w: Math.max(1, Math.round(item.width / drop.cellWidth)),
            h: Math.max(1, Math.round(item.height / drop.cellHeight))
        };
    }

    function start(dragged: Item, spanX: int, spanY: int): void {
        drop.cancel();
        const list = [];
        const state = {};
        for (const child of drop.layout.children) {
            if (child === dragged || child.applet === undefined || !child.applet || !child.visible) {
                continue;
            }
            state[String(list.length)] = drop.cellsOf(child);
            list.push(child);
        }
        drop.items = list;
        drop.origin = state;
        drop.shown = GridReorder.clone(state);
        drop.span = [Math.min(spanX, drop.columns), Math.min(spanY, drop.rows)];
        drop.target = null;
        drop.active = true;
    }

    function update(centerX: real, centerY: real): void {
        if (!drop.active) {
            return;
        }
        drop.center = Qt.point(centerX, centerY);
        const ctx = drop.context();
        const nearest = GridReorder.nearestArea(ctx, centerX, centerY, drop.span[0], drop.span[1], null);
        if (nearest.x < 0 || (drop.target && drop.target.x === nearest.x && drop.target.y === nearest.y)) {
            return;
        }
        drop.target = nearest;
        alarm.stop();
        const rect = { x: nearest.x, y: nearest.y, w: drop.span[0], h: drop.span[1] };
        if (!GridReorder.occupied(ctx, rect)) {
            drop.show(GridReorder.clone(drop.origin));
            drop.settleShakes();
            drop.outline(rect);
        } else if (!drop.reorder) {
            const vacant = GridReorder.nearestArea(ctx, centerX, centerY, drop.span[0], drop.span[1],
                                                   GridReorder.occupancy(ctx, drop.origin));
            drop.outline(vacant.x >= 0 ? { x: vacant.x, y: vacant.y, w: drop.span[0], h: drop.span[1] } : null);
        } else {
            const solution = GridReorder.calculate(ctx, centerX, centerY, drop.span[0], drop.span[1]);
            if (solution) {
                drop.hint(solution);
            }
            alarm.restart();
        }
    }

    function leave(): void {
        alarm.stop();
        drop.target = null;
        drop.show(GridReorder.clone(drop.origin));
        drop.settleShakes();
        drop.outline(null);
    }

    function finish(): var {
        alarm.stop();
        let result = null;
        if (drop.active && drop.target) {
            const ctx = drop.context();
            const rect = { x: drop.target.x, y: drop.target.y, w: drop.span[0], h: drop.span[1] };
            if (!GridReorder.occupied(ctx, rect)) {
                result = { x: rect.x, y: rect.y, state: GridReorder.clone(drop.origin) };
            } else if (drop.reorder) {
                result = GridReorder.calculate(ctx, drop.center.x, drop.center.y, drop.span[0], drop.span[1]);
            } else {
                const vacant = GridReorder.nearestArea(ctx, drop.center.x, drop.center.y, drop.span[0], drop.span[1],
                                                       GridReorder.occupancy(ctx, drop.origin));
                result = vacant.x >= 0 ? { x: vacant.x, y: vacant.y, state: GridReorder.clone(drop.origin) } : null;
            }
        }
        if (result) {
            const moved = [];
            for (const id in result.state) {
                const from = drop.origin[id];
                const to = result.state[id];
                if (from.x !== to.x || from.y !== to.y) {
                    drop.layout.releaseSpace(drop.items[Number(id)]);
                    moved.push(drop.items[Number(id)]);
                }
            }
            drop.show(result.state);
            drop.settling = drop.settling.concat(moved);
            settle.restart();
        } else {
            drop.show(GridReorder.clone(drop.origin));
        }
        drop.settleShakes();
        drop.outline(null);
        drop.active = false;
        drop.target = null;
        return result ? Qt.point(result.x, result.y) : null;
    }

    property var room: null

    function makeRoom(rect: var, direction: var): bool {
        if (!drop.active) {
            return false;
        }
        const solution = GridReorder.makeRoom(drop.context(), rect, direction);
        if (!solution) {
            return false;
        }
        drop.room = solution;
        drop.show(solution.state);
        drop.preview(solution.state);
        return true;
    }

    function commitRoom(): void {
        const solution = drop.room;
        drop.room = null;
        if (solution) {
            const moved = [];
            for (const id in solution.state) {
                const from = drop.origin[id];
                const to = solution.state[id];
                if (from.x !== to.x || from.y !== to.y) {
                    drop.layout.releaseSpace(drop.items[Number(id)]);
                    moved.push(drop.items[Number(id)]);
                }
            }
            drop.show(solution.state);
            drop.settling = drop.settling.concat(moved);
            settle.restart();
        } else {
            drop.show(GridReorder.clone(drop.origin));
        }
        drop.settleShakes();
        drop.active = false;
        drop.target = null;
    }

    function cancel(): void {
        if (!drop.active) {
            return;
        }
        alarm.stop();
        drop.show(GridReorder.clone(drop.origin));
        drop.settleShakes();
        drop.outline(null);
        drop.active = false;
        drop.target = null;
    }

    function show(state: var): void {
        for (const id in state) {
            const to = state[id];
            const now = drop.shown[id];
            if (now && now.x === to.x && now.y === to.y) {
                continue;
            }
            const item = drop.items[Number(id)];
            if (item) {
                if (drop.moves[id]) {
                    drop.moves[id].stop();
                    drop.moves[id].destroy();
                }
                drop.moves[id] = moveComponent.createObject(drop, {
                    item: item,
                    toX: to.x * drop.cellWidth,
                    toY: to.y * drop.cellHeight
                });
            }
        }
        drop.shown = GridReorder.clone(state);
    }

    function offsetFor(fromCell: var, toCell: var, sign: real): point {
        const dx = (toCell.x - fromCell.x) * drop.cellWidth;
        const dy = (toCell.y - fromCell.y) * drop.cellHeight;
        if (dx === 0 && dy === 0) {
            return Qt.point(0, 0);
        }
        if (dy === 0) {
            return Qt.point(sign * Math.sign(dx) * drop.magnitude, 0);
        }
        if (dx === 0) {
            return Qt.point(0, sign * Math.sign(dy) * drop.magnitude);
        }
        const angle = Math.atan(dy / dx);
        return Qt.point(sign * Math.sign(dx) * Math.abs(Math.cos(angle) * drop.magnitude),
                        sign * Math.sign(dy) * Math.abs(Math.sin(angle) * drop.magnitude));
    }

    function shake(id: string, mode: int, offset: point): void {
        if (!drop.motion) {
            return;
        }
        const item = drop.items[Number(id)];
        if (!item) {
            return;
        }
        const shakes = Object.assign({}, drop.shakes);
        let entry = shakes[id];
        if (!entry) {
            const translate = translateComponent.createObject(item);
            item.transform = [translate];
            entry = { item: item, translate: translate };
        }
        entry.mode = mode;
        entry.fromX = entry.translate.x;
        entry.fromY = entry.translate.y;
        entry.fromScale = item.scale;
        entry.toX = offset.x;
        entry.toY = offset.y;
        entry.toScale = 1 - 4 / Math.max(1, item.width - item.leftPadding - item.rightPadding);
        entry.start = Date.now();
        entry.delay = mode === 2 ? 0 : Math.random() * 60;
        shakes[id] = entry;
        drop.shakes = shakes;
    }

    function hint(solution: var): void {
        for (const id in drop.shakes) {
            if (solution.intersecting.indexOf(id) < 0) {
                drop.shake(id, 2, Qt.point(0, 0));
            }
        }
        for (const id of solution.intersecting) {
            const offset = drop.offsetFor(drop.origin[id], solution.state[id], 1);
            if (offset.x !== 0 || offset.y !== 0) {
                drop.shake(id, 0, offset);
            } else if (drop.shakes[id]) {
                drop.shake(id, 2, Qt.point(0, 0));
            }
        }
    }

    function preview(state: var): void {
        for (const id in state) {
            const offset = drop.offsetFor(drop.origin[id], state[id], -1);
            if (offset.x !== 0 || offset.y !== 0) {
                drop.shake(id, 1, offset);
            } else if (drop.shakes[id]) {
                drop.shake(id, 2, Qt.point(0, 0));
            }
        }
    }

    function settleShakes(): void {
        for (const id in drop.shakes) {
            if (drop.shakes[id].mode !== 2) {
                drop.shake(id, 2, Qt.point(0, 0));
            }
        }
    }

    function easeInOut(t: real): real {
        return Math.cos((t + 1) * Math.PI) / 2 + 0.5;
    }

    function stepShakes(): void {
        const now = Date.now();
        const shakes = Object.assign({}, drop.shakes);
        let changed = false;
        for (const id in shakes) {
            const entry = shakes[id];
            const elapsed = now - entry.start - entry.delay;
            let progress = 0;
            let done = false;
            if (entry.mode === 0) {
                progress = drop.easeInOut(Math.max(0, Math.min(1, elapsed / 650)));
            } else if (entry.mode === 1) {
                if (elapsed > 0) {
                    const cycle = elapsed / 300;
                    const fraction = cycle - Math.floor(cycle);
                    progress = drop.easeInOut(Math.floor(cycle) % 2 === 0 ? fraction : 1 - fraction);
                }
            } else {
                const t = Math.max(0, Math.min(1, elapsed / 150));
                progress = 1 - Math.pow(1 - t, 3);
                done = t >= 1;
            }
            entry.translate.x = entry.fromX + (entry.toX - entry.fromX) * progress;
            entry.translate.y = entry.fromY + (entry.toY - entry.fromY) * progress;
            entry.item.scale = entry.mode === 2
                ? entry.fromScale + (1 - entry.fromScale) * progress
                : entry.fromScale + (entry.toScale - entry.fromScale) * progress;
            if (done) {
                entry.item.transform = [];
                entry.item.scale = 1;
                entry.translate.destroy();
                delete shakes[id];
                changed = true;
            }
        }
        if (changed) {
            drop.shakes = shakes;
        }
    }

    function outline(rect: var): void {
        const outlines = drop.outlines.slice();
        const on = drop.outlineOn.slice();
        const current = drop.outlines[drop.outlineCurrent];
        if (rect && current && drop.outlineOn[drop.outlineCurrent] && current.x === rect.x && current.y === rect.y
                && current.w === rect.w && current.h === rect.h) {
            return;
        }
        on[drop.outlineCurrent] = false;
        if (rect) {
            const next = (drop.outlineCurrent + 1) % outlines.length;
            outlines[next] = rect;
            on[next] = true;
            drop.outlineCurrent = next;
        }
        drop.outlines = outlines;
        drop.outlineOn = on;
    }

    Timer {
        id: alarm
        interval: 650
        onTriggered: {
            const solution = GridReorder.calculate(drop.context(), drop.center.x, drop.center.y, drop.span[0], drop.span[1]);
            if (solution) {
                drop.show(solution.state);
                drop.preview(solution.state);
                drop.outline({ x: solution.x, y: solution.y, w: drop.span[0], h: drop.span[1] });
            } else {
                drop.show(GridReorder.clone(drop.origin));
                drop.settleShakes();
                drop.outline(null);
            }
        }
    }

    Timer {
        id: settle
        interval: 300
        onTriggered: {
            const items = drop.settling;
            drop.settling = [];
            for (const item of items) {
                if (item && drop.layout) {
                    drop.layout.positionItem(item);
                }
            }
        }
    }

    FrameAnimation {
        running: Object.keys(drop.shakes).length > 0
        onTriggered: drop.stepShakes()
    }

    Component {
        id: translateComponent
        Translate {}
    }

    Component {
        id: moveComponent

        ParallelAnimation {
            id: move

            property Item item
            property real toX
            property real toY

            running: true
            onFinished: {
                for (const id in drop.moves) {
                    if (drop.moves[id] === move) {
                        delete drop.moves[id];
                    }
                }
                move.destroy();
            }

            NumberAnimation {
                target: move.item
                property: "x"
                to: move.toX
                duration: Math.max(1, Math.round(150 * M3.motionScale))
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: move.item
                property: "y"
                to: move.toY
                duration: Math.max(1, Math.round(150 * M3.motionScale))
                easing.type: Easing.InOutSine
            }
        }
    }

    Repeater {
        model: 4

        delegate: Rectangle {
            id: frame

            required property int index
            readonly property var cell: drop.outlines[index]
            readonly property bool lit: drop.outlineOn[index]

            visible: cell !== null && opacity > 0
            x: cell ? cell.x * drop.cellWidth + 6 : 0
            y: cell ? cell.y * drop.cellHeight + 6 : 0
            width: cell ? cell.w * drop.cellWidth - 12 : 0
            height: cell ? cell.h * drop.cellHeight - 12 : 0
            radius: 16
            color: "transparent"
            border.width: 3
            border.color: drop.accent
            antialiasing: true
            opacity: 0

            onLitChanged: {
                fade.to = frame.lit ? 1 : 0;
                fade.restart();
            }

            NumberAnimation {
                id: fade
                target: frame
                property: "opacity"
                duration: Math.max(1, Math.round(500 * M3.motionScale))
                easing.type: Easing.OutQuint
            }
        }
    }
}
