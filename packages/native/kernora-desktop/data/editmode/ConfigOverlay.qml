/*
    SPDX-FileCopyrightText: 2019 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.containmentlayoutmanager as ContainmentLayoutManager
import org.kernora.m3

ContainmentLayoutManager.ConfigOverlay {
    id: overlay

    readonly property real frameRadius: M3.classic ? M3.cornerCard + 4 : 28
    readonly property bool onRight: overlay.rightAvailableSpace > toolbar.width + 20
    property QtObject appletSettings: null
    readonly property bool pointerNear: frameHover.hovered || toolbarHover.hovered || gapArea.containsMouse
        || dragArea.pressed || rotateHandle.pressed

    function handlePressed(): bool {
        for (const child of overlay.children) {
            if (child.resizeCorner !== undefined && child.pressed) {
                return true;
            }
        }
        return false;
    }

    function dismiss(): void {
        if (overlay.itemContainer && !overlay.handlePressed()) {
            overlay.itemContainer.editMode = false;
        }
    }

    HoverHandler {
        id: frameHover
    }

    Timer {
        interval: 900
        running: overlay.visible && overlay.open && !overlay.touchInteraction && !overlay.pointerNear
        onTriggered: overlay.dismiss()
    }

    Connections {
        target: appletsLayout
        function onEditModeChanged(): void {
            if (!appletsLayout.editMode) {
                overlay.dismiss();
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

    LayoutMirroring.enabled: false
    LayoutMirroring.childrenInherit: true

    opacity: open ? 1 : 0
    Behavior on opacity {
        OpacityAnimator {
            duration: M3.durationMedium2
            easing.type: Easing.Bezier
            easing.bezierCurve: M3.easingStandard
        }
    }

    SequentialAnimation {
        id: removeAnim

        NumberAnimation {
            target: overlay.itemContainer
            property: "scale"
            from: 1
            to: 0
            duration: M3.durationMedium4
            easing.type: Easing.Bezier
            easing.bezierCurve: M3.easingEmphasizedAccelerate
        }
        ScriptAction {
            script: {
                appletContainer.applet.plasmoid.internalAction("remove").trigger();
                appletContainer.editMode = false;
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -6
        radius: overlay.frameRadius
        color: M3.withAlpha(M3.primary, 0.06)
        border.width: 2
        border.color: M3.primary
    }

    MultiPointTouchArea {
        anchors.fill: parent
        property real previousMinX
        property real previousMinY
        property real previousMaxX
        property real previousMaxY
        property bool pinching: false
        mouseEnabled: false
        maximumTouchPoints: 2
        touchPoints: [
            TouchPoint { id: point1 },
            TouchPoint { id: point2 }
        ]

        onPressed: {
            overlay.itemContainer.layout.releaseSpace(overlay.itemContainer);
            previousMinX = point1.sceneX;
            previousMinY = point1.sceneY;
        }

        onUpdated: {
            let minX;
            let minY;
            let maxX;
            let maxY;

            if (point1.pressed && point2.pressed) {
                minX = Math.min(point1.sceneX, point2.sceneX);
                minY = Math.min(point1.sceneY, point2.sceneY);
                maxX = Math.max(point1.sceneX, point2.sceneX);
                maxY = Math.max(point1.sceneY, point2.sceneY);
            } else {
                minX = point1.pressed ? point1.sceneX : point2.sceneX;
                minY = point1.pressed ? point1.sceneY : point2.sceneY;
                maxX = -1;
                maxY = -1;
            }

            if (pinching === (point1.pressed && point2.pressed)) {
                overlay.itemContainer.x += minX - previousMinX;
                overlay.itemContainer.y += minY - previousMinY;
                if (pinching) {
                    overlay.itemContainer.width += maxX - previousMaxX + previousMinX - minX;
                    overlay.itemContainer.height += maxY - previousMaxY + previousMinY - minY;
                }
                overlay.itemContainer.layout.showPlaceHolderForItem(overlay.itemContainer);
            }

            pinching = point1.pressed && point2.pressed;
            previousMinX = minX;
            previousMinY = minY;
            previousMaxX = maxX;
            previousMaxY = maxY;
        }
        onReleased: {
            if (point1.pressed || point2.pressed) {
                return;
            }
            overlay.itemContainer.layout.positionItem(overlay.itemContainer);
            overlay.itemContainer.layout.hidePlaceHolder();
            pinching = false;
        }
        onCanceled: released()
    }

    component Handle: ContainmentLayoutManager.ResizeHandle {
        id: handle

        readonly property bool side: resizeCorner === ContainmentLayoutManager.ResizeHandle.Left
            || resizeCorner === ContainmentLayoutManager.ResizeHandle.Right
            || resizeCorner === ContainmentLayoutManager.ResizeHandle.Top
            || resizeCorner === ContainmentLayoutManager.ResizeHandle.Bottom
        readonly property bool vertical: resizeCorner === ContainmentLayoutManager.ResizeHandle.Left
            || resizeCorner === ContainmentLayoutManager.ResizeHandle.Right

        width: parent.touchInteraction ? 40 : 24
        height: width
        z: 999
        scale: parent.open ? 1 : 0

        Behavior on scale {
            NumberAnimation {
                duration: M3.durationMedium4
                easing.type: Easing.Bezier
                easing.bezierCurve: M3.easingEmphasizedDecelerate
            }
        }

        Rectangle {
            anchors.centerIn: parent
            visible: handle.side
            width: handle.vertical ? 10 : (handle.pressed ? 40 : 32)
            height: handle.vertical ? (handle.pressed ? 40 : 32) : 10
            radius: 5
            color: handle.resizeBlocked ? M3.error : M3.primary
            border.width: 2
            border.color: M3.surface

            Behavior on width {
                NumberAnimation {
                    duration: M3.durationShort4
                }
            }
            Behavior on height {
                NumberAnimation {
                    duration: M3.durationShort4
                }
            }
        }
    }

    Handle {
        resizeCorner: ContainmentLayoutManager.ResizeHandle.TopLeft
        anchors.horizontalCenter: parent.left
        anchors.verticalCenter: parent.top
    }
    Handle {
        resizeCorner: ContainmentLayoutManager.ResizeHandle.Left
        anchors.horizontalCenter: parent.left
        anchors.horizontalCenterOffset: -6
        anchors.verticalCenter: parent.verticalCenter
    }
    Handle {
        resizeCorner: ContainmentLayoutManager.ResizeHandle.BottomLeft
        anchors.horizontalCenter: parent.left
        anchors.verticalCenter: parent.bottom
    }
    Handle {
        resizeCorner: ContainmentLayoutManager.ResizeHandle.Bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.bottom
        anchors.verticalCenterOffset: 6
    }
    Handle {
        resizeCorner: ContainmentLayoutManager.ResizeHandle.BottomRight
        anchors.horizontalCenter: parent.right
        anchors.verticalCenter: parent.bottom
    }
    Handle {
        resizeCorner: ContainmentLayoutManager.ResizeHandle.Right
        anchors.horizontalCenter: parent.right
        anchors.horizontalCenterOffset: 6
        anchors.verticalCenter: parent.verticalCenter
    }
    Handle {
        resizeCorner: ContainmentLayoutManager.ResizeHandle.TopRight
        anchors.horizontalCenter: parent.right
        anchors.verticalCenter: parent.top
    }
    Handle {
        resizeCorner: ContainmentLayoutManager.ResizeHandle.Top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.top
        anchors.verticalCenterOffset: -6
    }

    Kirigami.ShadowedRectangle {
        id: toolbar

        readonly property var shadowSpec: M3.elevationOf("menu")

        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: {
            const difference = Math.round((toolbar.height - overlay.height) / 2);
            if (difference > 0) {
                if (difference > overlay.topAvailableSpace) {
                    return difference - overlay.topAvailableSpace;
                }
                if (difference > overlay.bottomAvailableSpace) {
                    return overlay.bottomAvailableSpace - difference;
                }
            }
            return 0;
        }
        x: overlay.onRight ? parent.width + 20 : -width - 20
        width: 56
        height: column.implicitHeight + 16
        radius: M3.classic ? M3.cornerCard : width / 2
        color: M3.surfaceContainerHigh
        shadow.size: M3.classic ? shadowSpec.blur : 16
        shadow.yOffset: M3.classic ? shadowSpec.offset : 3
        shadow.color: Qt.rgba(0, 0, 0, M3.dark ? 0.45 : 0.18)

        transform: Translate {
            x: overlay.open ? 0 : (overlay.onRight ? -toolbar.width : toolbar.width)

            Behavior on x {
                NumberAnimation {
                    duration: M3.durationMedium4
                    easing.type: Easing.Bezier
                    easing.bezierCurve: M3.easingEmphasizedDecelerate
                }
            }
        }

        HoverHandler {
            id: toolbarHover
        }

        MouseArea {
            id: gapArea
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            z: -1
            x: overlay.onRight ? -20 : 0
            width: parent.width + 20
            hoverEnabled: true
        }

        ColumnLayout {
            id: column
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 8
            spacing: 4

            MIconButton {
                readonly property QtObject qAction: applet ? applet.plasmoid.internalAction("configure") : null
                visible: qAction !== null && qAction.enabled && applet.plasmoid.hasConfigurationInterface
                icon: "configure"
                text: qAction ? qAction.text.replace(/&(?!&)/g, "") : ""
                onClicked: {
                    if (!overlay.appletSettings || !overlay.appletSettings.open(applet.plasmoid, overlay)) {
                        qAction.trigger();
                    }
                }
                Component.onCompleted: {
                    if (qAction) {
                        qAction.enabled = true;
                    }
                }
            }

            MIconButton {
                id: rotateButton
                readonly property QtObject qAction: applet ? applet.plasmoid.internalAction("rotate") : null
                icon: "object-rotate-left"
                text: rotateHandle.pressed ? "" : i18n("Click and drag to rotate")
                checkable: true
                checked: rotateHandle.pressed
                Component.onCompleted: {
                    if (qAction) {
                        qAction.enabled = true;
                    }
                }

                MouseArea {
                    id: rotateHandle
                    anchors.fill: parent
                    cursorShape: Qt.SizeAllCursor

                    property int startRotation
                    property real startCenterRelativeAngle

                    function pointAngle(pos: point): real {
                        const r = Math.sqrt(pos.x * pos.x + pos.y * pos.y);
                        const cosine = pos.x / r;
                        return pos.y >= 0 ? Math.acos(cosine) * (180 / Math.PI) : -Math.acos(cosine) * (180 / Math.PI);
                    }

                    function centerRelativePos(x: real, y: real): point {
                        const mousePos = overlay.itemContainer.parent.mapFromItem(rotateButton, x, y);
                        const centerPos = overlay.itemContainer.parent.mapFromItem(overlay.itemContainer, overlay.itemContainer.width / 2, overlay.itemContainer.height / 2);
                        mousePos.x -= centerPos.x;
                        mousePos.y -= centerPos.y;
                        return mousePos;
                    }

                    onPressed: mouse => {
                        mouse.accepted = true;
                        startRotation = overlay.itemContainer.rotation;
                        startCenterRelativeAngle = pointAngle(centerRelativePos(mouse.x, mouse.y));
                    }

                    onPositionChanged: mouse => {
                        const snap = 4;
                        let rotation = Math.round(pointAngle(centerRelativePos(mouse.x, mouse.y)) - startCenterRelativeAngle + startRotation);
                        if (rotation < 0) {
                            rotation += 360;
                        } else if (rotation >= 360) {
                            rotation %= 360;
                        }
                        for (const target of [0, 90, 180, 270, 360]) {
                            if (rotation > target - snap && rotation < target + snap) {
                                rotation = target % 360;
                            }
                        }
                        overlay.itemContainer.rotation = rotation;
                    }

                    onReleased: mouse => appletsLayout.save()
                }
            }

            MIconButton {
                visible: applet && (applet.plasmoid.backgroundHints & PlasmaCore.Types.ConfigurableBackground)
                icon: "window-maximize"
                text: checked ? i18n("Hide Background")
                              : i18n("Show Background")
                checkable: true
                checked: applet && (applet.plasmoid.effectiveBackgroundHints & PlasmaCore.Types.StandardBackground
                                    || applet.plasmoid.effectiveBackgroundHints & PlasmaCore.Types.TranslucentBackground)
                onClicked: {
                    const hints = applet.plasmoid.backgroundHints;
                    if (checked) {
                        applet.plasmoid.userBackgroundHints = hints & PlasmaCore.Types.StandardBackground || hints & PlasmaCore.Types.TranslucentBackground
                            ? hints : PlasmaCore.Types.StandardBackground;
                    } else {
                        applet.plasmoid.userBackgroundHints = hints & PlasmaCore.Types.ShadowBackground || hints & PlasmaCore.Types.NoBackground
                            ? hints : PlasmaCore.Types.ShadowBackground;
                    }
                }
            }

            Item {
                Layout.preferredWidth: 40
                Layout.preferredHeight: Math.max(48, overlay.height - 16 - rotateButton.height * 3)
                Layout.maximumHeight: 120
                Layout.alignment: Qt.AlignHCenter

                Rectangle {
                    anchors.fill: parent
                    radius: 20
                    color: M3.withAlpha(M3.surfaceContent, dragArea.containsPress ? M3.statePressed : dragArea.containsMouse ? M3.stateHover : 0)
                }
                MIcon {
                    anchors.centerIn: parent
                    size: 24
                    source: "drag-handle"
                }

                MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    drag.target: overlay.itemContainer
                    cursorShape: containsPress ? Qt.DragMoveCursor : Qt.OpenHandCursor
                    hoverEnabled: true
                    onPressed: mouse => appletsLayout.releaseSpace(overlay.itemContainer)
                    onPositionChanged: mouse => {
                        if (!pressed) {
                            return;
                        }
                        appletsLayout.showPlaceHolderForItem(overlay.itemContainer);
                        const dragPos = mapToItem(overlay.itemContainer, mouse.x, mouse.y);
                        overlay.itemContainer.userDrag(Qt.point(overlay.itemContainer.x, overlay.itemContainer.y), dragPos);
                    }
                    onReleased: mouse => {
                        appletsLayout.hidePlaceHolder();
                        appletsLayout.positionItem(overlay.itemContainer);
                    }
                }
            }

            MIconButton {
                visible: {
                    if (!applet) {
                        return false;
                    }
                    const action = applet.plasmoid.internalAction("remove");
                    return action && action.enabled || false;
                }
                icon: "user-trash"
                text: i18n("Remove")
                onClicked: removeAnim.restart()
                Component.onCompleted: {
                    const action = applet.plasmoid.internalAction("remove");
                    if (action) {
                        action.enabled = true;
                    }
                }
            }
        }
    }
}
