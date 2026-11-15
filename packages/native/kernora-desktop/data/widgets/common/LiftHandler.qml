/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

TapHandler {
    acceptedButtons: Qt.LeftButton
    gesturePolicy: TapHandler.DragThreshold
    longPressThreshold: 0.4

    function container(): Item {
        let item = parent;
        while (item) {
            if (item.editModeCondition !== undefined && item.layout !== undefined && item.editMode !== undefined) {
                return item;
            }
            item = item.parent;
        }
        return null;
    }

    onLongPressed: {
        const holder = container();
        if (holder && holder.layout && !holder.editMode) {
            holder.editMode = true;
        }
    }
}
