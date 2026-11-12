/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import "m3"

PlasmaCore.Dialog {
    id: popup

    required property QtObject backend
    property Item anchor: null
    property real hiddenAt: 0

    type: PlasmaCore.Dialog.AppletPopup
    location: Plasmoid.location
    backgroundHints: PlasmaCore.Dialog.NoBackground
    hideOnWindowDeactivate: true
    flags: Qt.WindowStaysOnTopHint
    visualParent: anchor
    visible: false

    function toggle(): void {
        if (visible) {
            visible = false;
        } else if (Date.now() - hiddenAt > 300 && backend.mediaActive) {
            visible = true;
            requestActivate();
        }
    }

    onVisibleChanged: {
        if (!visible) {
            hiddenAt = Date.now();
        }
    }

    mainItem: Item {
        width: 376
        height: card.implicitHeight + 28

        Keys.onEscapePressed: popup.visible = false

        Kirigami.ShadowedRectangle {
            anchors.fill: card
            radius: M3.cornerCard
            color: M3.surfaceContainerHigh
            shadow.size: 16
            shadow.yOffset: 4
            shadow.color: Qt.rgba(0, 0, 0, M3.dark ? 0.4 : 0.18)
        }

        MediaCard {
            id: card
            x: 8
            y: 8
            width: parent.width - 16
            backend: popup.backend
            onRequestClose: popup.visible = false
        }

        Connections {
            target: popup.backend
            function onMediaActiveChanged(): void {
                if (!popup.backend.mediaActive) {
                    popup.visible = false;
                }
            }
        }
    }
}
