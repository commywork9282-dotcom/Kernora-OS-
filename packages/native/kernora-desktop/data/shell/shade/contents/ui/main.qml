/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import "m3"

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    Plasmoid.title: i18n("Quick Settings")

    toolTipMainText: ""
    toolTipSubText: ""

    Backend {
        id: shadeBackend
    }

    ShadeController {
        id: shadeController
        inverted: Plasmoid.location === PlasmaCore.Types.TopEdge
    }

    fullRepresentation: StatusChip {
        id: chip
        controller: shadeController
        backend: shadeBackend
        Component.onCompleted: shade.anchorItem = chip
    }

    ShadeWindow {
        id: shade
        controller: shadeController
        backend: shadeBackend
        anchorItem: null
    }

    property bool acceptActivations: false
    Timer {
        interval: 2000
        running: true
        onTriggered: root.acceptActivations = true
    }
    readonly property bool arranging: (Plasmoid.containment?.corona?.editMode ?? false) || (Plasmoid.containment?.userConfiguring ?? false)
    onArrangingChanged: arrangingTimer.restart()
    Timer {
        id: arrangingTimer
        interval: 1500
    }
    onExpandedChanged: {
        if (root.acceptActivations && !root.arranging && !arrangingTimer.running) {
            shadeController.toggle();
        }
    }
}
