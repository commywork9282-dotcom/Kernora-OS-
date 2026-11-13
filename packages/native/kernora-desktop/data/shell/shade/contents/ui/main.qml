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
        Component.onCompleted: {
            shade.anchorItem = chip;
            mediaPopup.anchor = chip.mediaPill;
        }
        onMediaRequested: mediaPopup.toggle()
    }

    MediaPopup {
        id: mediaPopup
        backend: shadeBackend
    }

    ShadeWindow {
        id: shade
        controller: shadeController
        backend: shadeBackend
        anchorItem: null
    }

    property var glowbar: null
    Component {
        id: glowbarComponent
        Glowbar {}
    }
    Connections {
        target: shadeBackend
        function onPluggedInChanged(): void {
            if (!shadeBackend.pluggedIn || !shadeBackend.hasBattery || !root.acceptActivations) {
                return;
            }
            if (root.glowbar) {
                root.glowbar.destroy();
            }
            root.glowbar = glowbarComponent.createObject(null, {
                percent: shadeBackend.batteryPercent,
                screen: root.Window.window ? root.Window.window.screen : Qt.application.screens[0]
            });
        }
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
