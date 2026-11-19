/*
    SPDX-FileCopyrightText: 2019 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick
import QtQuick.Window
import QtQuick.Shapes
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.containmentlayoutmanager as ContainmentLayoutManager
import org.kernora.m3
import org.kernora.bartint
import "HomeGrid.js" as HomeGrid
import "GridReorder.js" as GridReorder

ContainmentLayoutManager.ConfigOverlay {
    id: overlay

    readonly property real insetLeft: itemContainer ? Math.min(itemContainer.leftPadding, 8) : 0
    readonly property real insetTop: itemContainer ? Math.min(itemContainer.topPadding, 8) : 0
    readonly property real insetRight: itemContainer ? Math.min(itemContainer.rightPadding, 8) : 0
    readonly property real insetBottom: itemContainer ? Math.min(itemContainer.bottomPadding, 8) : 0
    readonly property real frameRadius: 28
    readonly property bool darkInk: BarTint.darkInk(Screen.name, "left")
    readonly property color accent: darkInk ? M3.primaryFixedContent : M3.primaryFixed
    readonly property color onAccent: darkInk ? M3.primaryFixed : M3.primaryFixedContent
    readonly property string pluginName: applet && applet.plasmoid ? String(applet.plasmoid.pluginName) : ""
    readonly property bool canConfigure: !!applet && !!applet.plasmoid
        && (pluginName.startsWith(HomeGrid.prefix) ? HomeGrid.reconfigurable.indexOf(pluginName) >= 0
                                                   : applet.plasmoid.hasConfigurationInterface)
        && !!applet.plasmoid.internalAction("configure")
    property QtObject appletSettings: null
    property point pointer: Qt.point(-1, -1)
    property bool dragging: false
    property bool removing: false
    property point homeCell: Qt.point(0, 0)
    property size dragSpan: Qt.size(1, 1)
    readonly property bool overRemove: dragging && removeTarget.hit(pointer)

    function ms(value: real): int {
        return Math.max(1, Math.round(value * M3.motionScale));
    }

    function handlePressed(): bool {
        for (const child of overlay.children) {
            if (child.resizeCorner !== undefined && child.pressed) {
                return true;
            }
        }
        return false;
    }

    function dismiss(): void {
        if (overlay.itemContainer && !overlay.handlePressed() && !overlay.removing) {
            overlay.itemContainer.editMode = false;
        }
    }

    Timer {
        id: settle
        interval: 300
        onTriggered: {
            const item = overlay.itemContainer;
            if (item && item.layout) {
                item.layout.positionItem(item);
            }
        }
    }

    function openSettings(): void {
        if (!applet || !applet.plasmoid) {
            return;
        }
        if (!overlay.appletSettings || !overlay.appletSettings.open(applet.plasmoid, overlay)) {
            const action = applet.plasmoid.internalAction("configure");
            if (action) {
                action.enabled = true;
                action.trigger();
            }
        }
    }

    Component.onCompleted: {
        try {
            appletSettings = Qt.createQmlObject("import org.kernora.shell\nAppletSettings {}", overlay, "AppletSettings");
        } catch (error) {
            appletSettings = null;
        }
    }

    Connections {
        target: appletsLayout
        function onEditModeChanged(): void {
            if (!appletsLayout.editMode) {
                overlay.dismiss();
            }
        }
    }

    Connections {
        target: overlay.itemContainer
        function onUserDrag(newPosition: point, dragCenter: point): void {
            const item = overlay.itemContainer;
            const layout = item.layout;
            if (!overlay.dragging && layout && layout.cellWidth > 0 && layout.cellHeight > 0) {
                overlay.dragSpan = Qt.size(Math.max(1, Math.round(item.width / layout.cellWidth)),
                                           Math.max(1, Math.round(item.height / layout.cellHeight)));
                homeDrop.start(item, overlay.dragSpan.width, overlay.dragSpan.height);
            }
            overlay.dragging = true;
            overlay.pointer = Qt.point(newPosition.x + dragCenter.x, newPosition.y + dragCenter.y);
            if (overlay.overRemove) {
                homeDrop.leave();
            } else {
                homeDrop.update(newPosition.x + item.width / 2, newPosition.y + item.height / 2);
            }
        }
        function onDragActiveChanged(): void {
            if (overlay.itemContainer.dragActive) {
                return;
            }
            if (!overlay.dragging) {
                overlay.openVariants();
                return;
            }
            const remove = overlay.overRemove;
            overlay.dragging = false;
            if (remove) {
                homeDrop.cancel();
                removeAnimation.restart();
            } else {
                overlay.place(homeDrop.finish());
                overlay.dismiss();
            }
        }
    }

    function homeView(): var {
        const layout = overlay.itemContainer ? overlay.itemContainer.layout : null;
        if (!layout) {
            return null;
        }
        for (const child of layout.children) {
            if (child.view && typeof child.view.openAppWidgets === "function") {
                return child.view;
            }
        }
        return null;
    }

    function closeVariants(): void {
        variantsDelay.stop();
        const home = overlay.homeView();
        if (home) {
            home.closeAppWidgets();
        }
    }

    Timer {
        id: variantsDelay
        interval: 250
        onTriggered: {
            const item = overlay.itemContainer;
            if (item && !item.dragActive) {
                overlay.openVariants();
            }
        }
    }

    function openVariants(): void {
        const item = overlay.itemContainer;
        if (!overlay.open || overlay.dragging || !item || item.dragActive || !item.layout || item.layout.editMode) {
            return;
        }
        const home = overlay.homeView();
        if (home) {
            home.openAppWidgets(item);
        }
    }

    onDraggingChanged: {
        if (overlay.dragging) {
            overlay.closeVariants();
        }
    }

    onOpenChanged: {
        const item = overlay.itemContainer;
        if (overlay.open && item && item.layout && item.layout.cellWidth > 0) {
            overlay.homeCell = Qt.point(Math.round(item.x / item.layout.cellWidth), Math.round(item.y / item.layout.cellHeight));
        }
        if (overlay.open) {
            variantsDelay.restart();
        } else {
            overlay.dragging = false;
            homeDrop.cancel();
            overlay.closeVariants();
        }
    }

    function place(cell: var): void {
        const item = overlay.itemContainer;
        const layout = item ? item.layout : null;
        if (!layout || layout.cellWidth <= 0 || layout.cellHeight <= 0) {
            return;
        }
        const spot = cell !== null ? cell : overlay.homeCell;
        const columns = overlay.dragSpan.width;
        const rows = overlay.dragSpan.height;
        layout.releaseSpace(item);
        item.x = spot.x * layout.cellWidth;
        item.y = spot.y * layout.cellHeight;
        item.width = columns * layout.cellWidth;
        item.height = rows * layout.cellHeight;
        settle.restart();
    }

    HomeDrop {
        id: homeDrop
        layout: overlay.itemContainer ? overlay.itemContainer.layout : null
        accent: overlay.accent
    }

    LayoutMirroring.enabled: false
    LayoutMirroring.childrenInherit: true

    opacity: open ? 1 : 0
    Behavior on opacity {
        OpacityAnimator {
            duration: M3.durationShort4
        }
    }

    Binding {
        target: overlay.itemContainer
        property: "opacity"
        value: overlay.overRemove ? 0.65 : 1
        when: overlay.itemContainer !== null && !overlay.removing
    }

    SequentialAnimation {
        id: removeAnimation

        ScriptAction {
            script: overlay.removing = true
        }
        ParallelAnimation {
            NumberAnimation {
                target: overlay.itemContainer
                property: "scale"
                to: 0
                duration: overlay.ms(200)
                easing.type: Easing.Bezier
                easing.bezierCurve: [0.3, 0, 0.8, 0.15, 1, 1]
            }
            NumberAnimation {
                target: overlay.itemContainer
                property: "opacity"
                to: 0
                duration: overlay.ms(200)
            }
        }
        ScriptAction {
            script: {
                const action = appletContainer.applet.plasmoid.internalAction("remove");
                if (action) {
                    action.enabled = true;
                    action.trigger();
                }
                appletContainer.editMode = false;
            }
        }
    }

    MouseArea {
        parent: overlay.itemContainer ? overlay.itemContainer.layout : null
        anchors.fill: parent
        z: 0.9
        enabled: overlay.open && !overlay.dragging
        acceptedButtons: Qt.AllButtons
        onPressed: mouse => {
            overlay.dismiss();
            mouse.accepted = false;
        }
    }

    property bool frameFree: false
    property real frameLeft: 0
    property real frameTop: 0
    property real frameWidth: 0
    property real frameHeight: 0
    readonly property real frameX: frameFree && itemContainer ? frameLeft - itemContainer.x : 0
    readonly property real frameY: frameFree && itemContainer ? frameTop - itemContainer.y : 0
    readonly property real frameW: frameFree ? frameWidth : width
    readonly property real frameH: frameFree ? frameHeight : height

    property int resizeEdge: 0
    property point resizePress: Qt.point(0, 0)
    property rect resizeBase: Qt.rect(0, 0, 0, 0)
    property var resizeCells: null
    property int runningH: 0
    property int runningV: 0
    property size minimumSpan: Qt.size(1, 1)

    readonly property int edgeLeft: 1
    readonly property int edgeTop: 2
    readonly property int edgeRight: 4
    readonly property int edgeBottom: 8

    function cellsOf(item: Item): var {
        const layout = item.layout;
        return {
            x: Math.round(item.x / layout.cellWidth),
            y: Math.round(item.y / layout.cellHeight),
            w: Math.max(1, Math.round(item.width / layout.cellWidth)),
            h: Math.max(1, Math.round(item.height / layout.cellHeight))
        };
    }

    function beginResize(edge: int, point: point): void {
        overlay.closeVariants();
        const item = overlay.itemContainer;
        const layout = item ? item.layout : null;
        if (!layout || layout.cellWidth <= 0 || layout.cellHeight <= 0) {
            return;
        }
        frameSnap.stop();
        overlay.resizeEdge = edge;
        overlay.resizePress = point;
        overlay.resizeBase = Qt.rect(item.x, item.y, item.width, item.height);
        overlay.frameLeft = item.x;
        overlay.frameTop = item.y;
        overlay.frameWidth = item.width;
        overlay.frameHeight = item.height;
        overlay.frameFree = true;
        overlay.resizeCells = overlay.cellsOf(item);
        overlay.runningH = 0;
        overlay.runningV = 0;
        const minimum = HomeGrid.minimumSpan(overlay.pluginName);
        overlay.minimumSpan = Qt.size(minimum[0], minimum[1]);
        homeDrop.start(item, overlay.resizeCells.w, overlay.resizeCells.h);
        layout.releaseSpace(item);
    }

    function moveResize(point: point): void {
        const item = overlay.itemContainer;
        const layout = item ? item.layout : null;
        if (!layout || overlay.resizeEdge === 0) {
            return;
        }
        const base = overlay.resizeBase;
        const touch = overlay.touchInteraction ? 40 : 24;
        const left = overlay.resizeEdge === overlay.edgeLeft;
        const right = overlay.resizeEdge === overlay.edgeRight;
        const top = overlay.resizeEdge === overlay.edgeTop;
        const bottom = overlay.resizeEdge === overlay.edgeBottom;
        let dx = point.x - overlay.resizePress.x;
        let dy = point.y - overlay.resizePress.y;
        if (left) {
            dx = Math.max(-base.x, Math.min(base.width - 2 * touch, dx));
        } else if (right) {
            dx = Math.max(2 * touch - base.width, Math.min(layout.width - base.x - base.width, dx));
        } else {
            dx = 0;
        }
        if (top) {
            dy = Math.max(-base.y, Math.min(base.height - 2 * touch, dy));
        } else if (bottom) {
            dy = Math.max(2 * touch - base.height, Math.min(layout.height - base.y - base.height, dy));
        } else {
            dy = 0;
        }
        overlay.frameLeft = left ? base.x + dx : base.x;
        overlay.frameWidth = left ? base.width - dx : (right ? base.width + dx : base.width);
        overlay.frameTop = top ? base.y + dy : base.y;
        overlay.frameHeight = top ? base.height - dy : (bottom ? base.height + dy : base.height);

        const hInc = GridReorder.spanIncrement(dx / layout.cellWidth - overlay.runningH);
        const vInc = GridReorder.spanIncrement(dy / layout.cellHeight - overlay.runningV);
        if (hInc === 0 && vInc === 0) {
            return;
        }
        const cells = overlay.resizeCells;
        const columns = homeDrop.columns;
        const rows = homeDrop.rows;
        const h = GridReorder.bound(cells.x, cells.x + cells.w, left, right, hInc,
                                    Math.min(overlay.minimumSpan.width, cells.w), columns, columns);
        const v = GridReorder.bound(cells.y, cells.y + cells.h, top, bottom, vInc,
                                    Math.min(overlay.minimumSpan.height, cells.h), rows, rows);
        if (h.delta === 0 && v.delta === 0) {
            return;
        }
        const direction = [h.delta !== 0 ? (left ? -1 : 1) : 0, v.delta !== 0 ? (top ? -1 : 1) : 0];
        const rect = { x: h.start, y: v.start, w: h.end - h.start, h: v.end - v.start };
        if (!homeDrop.makeRoom(rect, direction)) {
            return;
        }
        overlay.resizeCells = rect;
        overlay.runningH += h.delta;
        overlay.runningV += v.delta;
        item.x = rect.x * layout.cellWidth;
        item.y = rect.y * layout.cellHeight;
        item.width = rect.w * layout.cellWidth;
        item.height = rect.h * layout.cellHeight;
    }

    function endResize(): void {
        const item = overlay.itemContainer;
        if (overlay.resizeEdge === 0 || !item) {
            return;
        }
        overlay.resizeEdge = 0;
        homeDrop.commitRoom();
        settle.restart();
        frameSnap.toLeft = item.x;
        frameSnap.toTop = item.y;
        frameSnap.toWidth = item.width;
        frameSnap.toHeight = item.height;
        frameSnap.restart();
    }

    ParallelAnimation {
        id: frameSnap

        property real toLeft
        property real toTop
        property real toWidth
        property real toHeight

        onFinished: overlay.frameFree = false

        NumberAnimation {
            target: overlay
            property: "frameLeft"
            to: frameSnap.toLeft
            duration: overlay.ms(150)
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: overlay
            property: "frameTop"
            to: frameSnap.toTop
            duration: overlay.ms(150)
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: overlay
            property: "frameWidth"
            to: frameSnap.toWidth
            duration: overlay.ms(150)
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: overlay
            property: "frameHeight"
            to: frameSnap.toHeight
            duration: overlay.ms(150)
            easing.type: Easing.InOutSine
        }
    }

    Rectangle {
        x: overlay.frameX + overlay.insetLeft - 1
        y: overlay.frameY + overlay.insetTop - 1
        width: overlay.frameW - overlay.insetLeft - overlay.insetRight + 2
        height: overlay.frameH - overlay.insetTop - overlay.insetBottom + 2
        radius: overlay.frameRadius + 1
        color: "transparent"
        border.width: 2
        border.color: overlay.accent
        visible: !overlay.dragging && !overlay.removing
        antialiasing: true
    }

    component Handle: Item {
        id: handle

        property int resizeCorner
        readonly property bool pressed: handleMouse.pressed
        readonly property bool active: overlay.resizeEdge === resizeCorner

        width: overlay.touchInteraction ? 40 : 24
        height: width
        z: 999
        visible: !overlay.dragging && !overlay.removing
        scale: overlay.open ? 1 : 0
        opacity: overlay.resizeEdge === 0 || active ? 1 : 0

        Behavior on scale {
            NumberAnimation {
                duration: overlay.ms(250)
                easing.type: Easing.Bezier
                easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1]
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: handle.pressed ? 16 : 12
            height: width
            radius: width / 2
            color: overlay.accent
            antialiasing: true

            Behavior on width {
                NumberAnimation {
                    duration: overlay.ms(150)
                }
            }
        }

        MouseArea {
            id: handleMouse

            anchors.fill: parent
            preventStealing: true
            cursorShape: handle.resizeCorner === overlay.edgeLeft || handle.resizeCorner === overlay.edgeRight
                ? Qt.SizeHorCursor : Qt.SizeVerCursor
            onPressed: mouse => {
                const layout = overlay.itemContainer ? overlay.itemContainer.layout : null;
                if (layout) {
                    overlay.beginResize(handle.resizeCorner, handleMouse.mapToItem(layout, mouse.x, mouse.y));
                }
            }
            onPositionChanged: mouse => {
                const layout = overlay.itemContainer ? overlay.itemContainer.layout : null;
                if (layout && pressed) {
                    overlay.moveResize(handleMouse.mapToItem(layout, mouse.x, mouse.y));
                }
            }
            onReleased: overlay.endResize()
            onCanceled: overlay.endResize()
        }
    }

    Handle {
        resizeCorner: overlay.edgeLeft
        x: overlay.frameX + overlay.insetLeft - width / 2
        y: overlay.frameY + overlay.frameH / 2 - height / 2
    }
    Handle {
        resizeCorner: overlay.edgeTop
        x: overlay.frameX + overlay.frameW / 2 - width / 2
        y: overlay.frameY + overlay.insetTop - height / 2
    }
    Handle {
        resizeCorner: overlay.edgeRight
        x: overlay.frameX + overlay.frameW - overlay.insetRight - width / 2
        y: overlay.frameY + overlay.frameH / 2 - height / 2
    }
    Handle {
        resizeCorner: overlay.edgeBottom
        x: overlay.frameX + overlay.frameW / 2 - width / 2
        y: overlay.frameY + overlay.frameH - overlay.insetBottom - height / 2
    }

    Rectangle {
        id: reconfigure

        x: overlay.frameX + overlay.frameW - overlay.insetRight - width - 8
        y: overlay.frameY + overlay.frameH - overlay.insetBottom - height - 8
        width: 36
        height: 36
        radius: 14
        color: overlay.accent
        visible: overlay.canConfigure && !overlay.dragging && !overlay.removing
        scale: overlay.open ? 1 : 0
        antialiasing: true

        Behavior on scale {
            NumberAnimation {
                duration: overlay.ms(250)
                easing.type: Easing.Bezier
                easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1]
            }
        }

        MStateLayer {
            radius: reconfigure.radius
            color: overlay.onAccent
            hovered: reconfigureMouse.containsMouse
            pressed: reconfigureMouse.pressed
            pressPoint: Qt.point(reconfigureMouse.mouseX, reconfigureMouse.mouseY)
        }

        Item {
            anchors.centerIn: parent
            width: 24
            height: 24

            Shape {
                y: 24
                width: 960
                height: 960
                scale: 0.025
                transformOrigin: Item.TopLeft
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: -1
                    strokeColor: "transparent"
                    fillColor: overlay.onAccent
                    PathSvg {
                        path: "M200-200h57l391-391-57-57-391 391v57Zm-40 80q-17 0-28.5-11.5T120-160v-97q0-16 6-30.5t17-25.5l505-504q12-11 26.5-17t30.5-6q16 0 31 6t26 18l55 56q12 11 17.5 26t5.5 30q0 16-5.5 30.5T817-647L313-143q-11 11-25.5 17t-30.5 6h-97Zm600-584-56-56 56 56Zm-141 85-28-29 57 57-29-28Z"
                    }
                }
            }
        }

        MouseArea {
            id: reconfigureMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: overlay.openSettings()
        }

        Accessible.role: Accessible.Button
        Accessible.name: i18nd("kernora-ui", "Change widget settings")
    }

    Item {
        id: removeTarget

        readonly property real padding: 14
        readonly property bool shown: overlay.dragging && overlay.open

        function hit(point: point): bool {
            if (!shown || point.x < 0) {
                return false;
            }
            return point.x >= x - padding && point.x <= x + width + padding
                && point.y >= y - padding && point.y <= y + height + padding;
        }

        parent: overlay.itemContainer ? overlay.itemContainer.layout : null
        z: 3
        x: parent ? Math.round((parent.width - width) / 2) : 0
        y: 32
        width: removeRow.implicitWidth + 2 * padding + 8
        height: 48
        opacity: shown ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: overlay.ms(200)
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: overlay.overRemove ? overlay.accent : "transparent"
            border.width: overlay.overRemove ? 0 : 2
            border.color: overlay.accent
            antialiasing: true

            Behavior on color {
                ColorAnimation {
                    duration: overlay.ms(150)
                }
            }
        }

        Row {
            id: removeRow

            anchors.centerIn: parent
            spacing: 8

            MIcon {
                anchors.verticalCenter: parent.verticalCenter
                size: 20
                source: "window-close"
                color: overlay.overRemove ? overlay.onAccent : (overlay.darkInk ? BarTint.dark : BarTint.light)
            }

            MText {
                anchors.verticalCenter: parent.verticalCenter
                role: "titleMedium"
                text: i18ndc("kernora-ui", "drop target that takes a widget off the home screen", "Remove")
                color: overlay.overRemove ? overlay.onAccent : (overlay.darkInk ? BarTint.dark : BarTint.light)
            }
        }
    }
}
