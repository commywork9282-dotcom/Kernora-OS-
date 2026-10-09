/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.private.clipboard as Klipper
import "m3"

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.status: PlasmaCore.Types.HiddenStatus
    Plasmoid.title: i18n("Clipboard")
    Plasmoid.icon: "edit-paste"

    toolTipMainText: ""
    toolTipSubText: ""

    Klipper.KlipperInterface {
        id: klipper
    }
    Klipper.HistoryModel {
        id: clipboardHistory
    }

    fullRepresentation: Item {
        Layout.preferredWidth: 40
        Layout.preferredHeight: 40

        MIcon {
            anchors.centerIn: parent
            source: "edit-paste"
        }
    }

    ClipboardWindow {
        id: sheetWindow
        history: clipboardHistory
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
            sheetWindow.toggle();
        }
    }
}
