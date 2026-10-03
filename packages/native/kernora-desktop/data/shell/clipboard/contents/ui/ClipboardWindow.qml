/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

PlasmaCore.Dialog {
    id: root

    required property QtObject history

    readonly property rect availableRect: {
        const containment = Plasmoid.containment;
        if (!containment) {
            return Qt.rect(0, 0, 1280, 800);
        }
        return Qt.rect(containment.screenGeometry.x + containment.availableScreenRect.x,
                       containment.screenGeometry.y + containment.availableScreenRect.y,
                       containment.availableScreenRect.width,
                       containment.availableScreenRect.height);
    }
    readonly property int edgeGap: 12

    type: PlasmaCore.Dialog.AppletPopup
    location: PlasmaCore.Types.Floating
    hideOnWindowDeactivate: true
    flags: Qt.WindowStaysOnTopHint
    visible: false

    x: availableRect.x + Math.round((availableRect.width - width) / 2)
    y: availableRect.y + availableRect.height - height - edgeGap

    function toggle(): void {
        visible = !visible;
    }

    onVisibleChanged: {
        if (visible) {
            sheet.reset(Plasmoid.configuration.startPage);
            requestActivate();
            sheet.forceActiveFocus();
        }
    }

    mainItem: ClipboardSheet {
        id: sheet
        history: root.history
        maximumHeight: Math.round(root.availableRect.height * 0.7)
        onRequestClose: root.visible = false
    }
}
