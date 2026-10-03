/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import "m3"

PlasmaCore.Dialog {
    id: root

    required property QtObject controller
    required property QtObject backend
    required property Item anchorItem

    readonly property rect screenRect: Plasmoid.containment ? Plasmoid.containment.screenGeometry : Qt.rect(0, 0, 1280, 800)

    readonly property int edgeGap: 8

    type: PlasmaCore.Dialog.AppletPopup
    location: PlasmaCore.Types.Floating
    backgroundHints: PlasmaCore.Dialog.NoBackground
    hideOnWindowDeactivate: false
    flags: Qt.WindowStaysOnTopHint

    visible: controller.shown

    property double openedAt: 0
    readonly property bool opening: controller.opening
    onOpeningChanged: {
        if (opening) {
            openedAt = Date.now();
        }
    }
    x: screenRect.x
    y: screenRect.y

    onVisibleChanged: {
        if (visible) {
            stage.alignSheet();
            sheet.scrollToTop();
            requestActivate();
            sheet.forceActiveFocus();
        }
    }

    onWindowDeactivated: {
        if (!controller.dragging && controller.opening) {
            controller.close();
        }
    }

    mainItem: Item {
        id: stage

        width: root.screenRect.width
        height: root.screenRect.height

        property real anchorRight: width - root.edgeGap
        property real anchorTop: height

        function alignSheet(): void {
            if (!root.anchorItem) {
                return;
            }
            const topRight = root.anchorItem.mapToGlobal(root.anchorItem.width, 0);
            anchorRight = topRight.x - root.screenRect.x;
            anchorTop = topRight.y - root.screenRect.y;
        }

        readonly property real restBottom: Math.min(height - root.edgeGap, anchorTop - 8 - root.edgeGap)

        Keys.onEscapePressed: root.controller.close()

        Keys.onPressed: event => {
            const modifierOnly = event.key === Qt.Key_Meta || event.key === Qt.Key_Super_L
                || event.key === Qt.Key_Super_R;
            const settling = Date.now() - root.openedAt < 400;
            if ((event.modifiers & Qt.MetaModifier) && !modifierOnly
                    && !event.isAutoRepeat && !settling) {
                root.controller.close();
                event.accepted = true;
            }
        }

        Rectangle {
            anchors.fill: parent
            color: M3.scrim
            opacity: 0.32 * Math.max(0, Math.min(1, root.controller.progress))
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.controller.close()
            onWheel: wheel => {
                const point = sheet.mapFromItem(stage, wheel.x, wheel.y);
                if (sheet.scrollable && sheet.contains(point)) {
                    return;
                }
                gestures.handleWheel(wheel);
            }
        }

        ShadeSheet {
            id: sheet

            backend: root.backend
            progress: root.controller.progress
            width: Math.min(implicitWidth, stage.width - 2 * root.edgeGap)
            height: Math.min(implicitHeight, stage.restBottom - root.edgeGap)

            x: Math.max(root.edgeGap, Math.min(stage.width - width - root.edgeGap, stage.anchorRight - width))

            readonly property real restY: stage.restBottom - height
            readonly property real hiddenY: stage.height + 48
            y: restY + (hiddenY - restY) * (1 - root.controller.progress)

            onHeightChanged: root.controller.travel = hiddenY - restY
            Component.onCompleted: root.controller.travel = hiddenY - restY

            onRequestClose: root.controller.close()
            Keys.onEscapePressed: root.controller.close()

            onHandleDragStarted: root.controller.beginDrag()
            onHandleDragMoved: upwards => root.controller.dragTo(upwards)
            onHandleDragEnded: root.controller.endDrag()

            DragHandler {
                id: sheetDrag
                enabled: !sheet.scrollable
                target: null
                xAxis.enabled: false
                dragThreshold: 8
                grabPermissions: PointerHandler.CanTakeOverFromItems
                    | PointerHandler.CanTakeOverFromHandlersOfDifferentType
                    | PointerHandler.ApprovesTakeOverByAnything
                onActiveChanged: {
                    if (active) {
                        root.controller.beginDrag();
                    } else {
                        root.controller.endDrag();
                    }
                }
                onTranslationChanged: {
                    if (active) {
                        root.controller.dragTo(-translation.y);
                    }
                }
            }

            WheelHandler {
                id: gestures
                enabled: !sheet.scrollable
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

                function handleWheel(event: var): void {
                    if (event.pixelDelta.y !== 0) {
                        const up = event.inverted ? -event.pixelDelta.y : event.pixelDelta.y;
                        root.controller.scrollBy(up);
                    } else if (event.angleDelta.y !== 0) {
                        const up = event.inverted ? -event.angleDelta.y : event.angleDelta.y;
                        root.controller.wheelNotch(up > 0);
                    }
                }

                onWheel: event => handleWheel(event)
            }
        }
    }
}
