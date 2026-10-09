/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick
import org.kde.kwindowsystem

Item {
    id: root

    property string pluginName
    property Item preview
    readonly property bool active: mouseDrag.active || touchDrag.active

    signal started()
    signal finished()

    Drag.dragType: Drag.Automatic
    Drag.supportedActions: Qt.MoveAction | Qt.LinkAction
    Drag.mimeData: {
        "text/x-plasmoidservicename": root.pluginName
    }
    Drag.onDragStarted: {
        KWindowSystem.showingDesktop = true;
        root.started();
    }
    Drag.onDragFinished: root.finished()

    function follow(handler: DragHandler): void {
        if (!handler.active) {
            root.Drag.active = false;
            root.Drag.imageSource = "";
            return;
        }
        root.preview.grabToImage(result => {
            if (!handler.active) {
                return;
            }
            root.Drag.imageSource = result.url;
            root.Drag.active = true;
        }, Qt.size(Math.round(root.preview.width), Math.round(root.preview.height)));
    }

    DragHandler {
        id: mouseDrag
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        enabled: root.enabled
        onActiveChanged: root.follow(mouseDrag)
    }

    DragHandler {
        id: touchDrag
        target: null
        acceptedDevices: PointerDevice.Stylus | PointerDevice.TouchScreen
        enabled: root.enabled
        yAxis.enabled: false
        onActiveChanged: root.follow(touchDrag)
    }
}
