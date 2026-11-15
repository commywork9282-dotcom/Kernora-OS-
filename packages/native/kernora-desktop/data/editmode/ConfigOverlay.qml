/*
    SPDX-FileCopyrightText: 2019 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick
import QtQuick.Window
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.containmentlayoutmanager as ContainmentLayoutManager
import org.kernora.m3
import org.kernora.bartint
import "HomeGrid.js" as HomeGrid

ContainmentLayoutManager.ConfigOverlay {
    id: overlay

    readonly property real insetLeft: itemContainer ? itemContainer.leftPadding : 0
    readonly property real insetTop: itemContainer ? itemContainer.topPadding : 0
    readonly property real insetRight: itemContainer ? itemContainer.rightPadding : 0
    readonly property real insetBottom: itemContainer ? itemContainer.bottomPadding : 0
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

    function snap(): void {
        const item = overlay.itemContainer;
        const layout = item ? item.layout : null;
        if (!layout || layout.cellWidth <= 0 || layout.cellHeight <= 0) {
            return;
        }
        const columns = Math.max(1, Math.round(item.width / layout.cellWidth));
        const rows = Math.max(1, Math.round(item.height / layout.cellHeight));
        layout.releaseSpace(item);
        item.x = Math.round(item.x / layout.cellWidth) * layout.cellWidth;
        item.y = Math.round(item.y / layout.cellHeight) * layout.cellHeight;
        item.width = columns * layout.cellWidth;
        item.height = rows * layout.cellHeight;
        settle.restart();
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

    onOpenChanged: {
        const item = overlay.itemContainer;
        if (overlay.open && item && item.layout && item.layout.cellWidth > 0) {
            overlay.homeCell = Qt.point(Math.round(item.x / item.layout.cellWidth), Math.round(item.y / item.layout.cellHeight));
        }
        if (!overlay.open) {
            overlay.dragging = false;
            homeDrop.cancel();
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

    Rectangle {
        x: overlay.insetLeft - 1
        y: overlay.insetTop - 1
        width: overlay.width - overlay.insetLeft - overlay.insetRight + 2
        height: overlay.height - overlay.insetTop - overlay.insetBottom + 2
        radius: overlay.frameRadius + 1
        color: "transparent"
        border.width: 2
        border.color: overlay.accent
        visible: !overlay.dragging && !overlay.removing
        antialiasing: true
    }

    component Handle: ContainmentLayoutManager.ResizeHandle {
        id: handle

        width: overlay.touchInteraction ? 40 : 24
        height: width
        z: 999
        visible: !overlay.dragging && !overlay.removing
        scale: overlay.open ? 1 : 0

        onPressedChanged: {
            if (!pressed) {
                overlay.snap();
            }
        }

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
            color: handle.resizeBlocked ? M3.error : overlay.accent
            antialiasing: true

            Behavior on width {
                NumberAnimation {
                    duration: overlay.ms(150)
                }
            }
        }
    }

    Handle {
        resizeCorner: ContainmentLayoutManager.ResizeHandle.Left
        x: overlay.insetLeft - width / 2
        anchors.verticalCenter: parent.verticalCenter
    }
    Handle {
        resizeCorner: ContainmentLayoutManager.ResizeHandle.Top
        y: overlay.insetTop - height / 2
        anchors.horizontalCenter: parent.horizontalCenter
    }
    Handle {
        resizeCorner: ContainmentLayoutManager.ResizeHandle.Right
        x: overlay.width - overlay.insetRight - width / 2
        anchors.verticalCenter: parent.verticalCenter
    }
    Handle {
        resizeCorner: ContainmentLayoutManager.ResizeHandle.Bottom
        y: overlay.height - overlay.insetBottom - height / 2
        anchors.horizontalCenter: parent.horizontalCenter
    }

    Rectangle {
        id: reconfigure

        x: overlay.width - overlay.insetRight - width - 8
        y: overlay.height - overlay.insetBottom - height - 8
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

        MIcon {
            anchors.centerIn: parent
            size: 24
            source: "document-edit"
            color: overlay.onAccent
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
