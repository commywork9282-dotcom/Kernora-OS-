/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    readonly property bool inPanel: Plasmoid.formFactor !== PlasmaCore.Types.Planar
    preferredRepresentation: inPanel ? null : fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    switchWidth: Plasmoid.configuration.placed ? 0 : 120
    switchHeight: Plasmoid.configuration.placed ? 0 : 120

    Timer {
        running: !Plasmoid.configuration.placed
        interval: 2000
        onTriggered: Plasmoid.configuration.placed = true
    }

    readonly property string style: {
        switch (Plasmoid.configuration.style) {
        case "analog":
        case "digital":
            return Plasmoid.configuration.style;
        default:
            return "stacked";
        }
    }
    property date now: new Date()

    toolTipMainText: Qt.locale().toString(now, Locale.LongFormat)
    toolTipSubText: ""

    Timer {
        interval: root.style === "analog" ? 1000 : 1000 * (60 - root.now.getSeconds())
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    fullRepresentation: Item {
        LiftHandler {}

        Layout.preferredWidth: root.inPanel ? (root.style === "digital" ? 262 : root.style === "stacked" ? 196 : 270) : -1
        Layout.preferredHeight: root.inPanel ? (root.style === "digital" ? 190 : 270) : -1
        Layout.minimumWidth: 80
        Layout.minimumHeight: 80
        Layout.maximumWidth: root.inPanel ? Layout.preferredWidth : Infinity
        Layout.maximumHeight: root.inPanel ? Layout.preferredHeight : Infinity

        ClockFace {
            anchors.fill: parent
            style: root.style
            now: root.now
        }
    }
}
