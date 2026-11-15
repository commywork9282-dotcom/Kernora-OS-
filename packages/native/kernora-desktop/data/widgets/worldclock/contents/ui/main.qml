/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.private.digitalclock as DigitalClock

PlasmoidItem {
    id: root

    readonly property bool inPanel: Plasmoid.formFactor !== PlasmaCore.Types.Planar
    preferredRepresentation: inPanel ? null : fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    switchWidth: Plasmoid.configuration.placed ? 0 : 120
    switchHeight: Plasmoid.configuration.placed ? 0 : 120

    readonly property string zone: Plasmoid.configuration.timeZone
    readonly property string source: zone.length > 0 ? zone : "Local"
    readonly property var zoneData: time.data[source] ?? null
    readonly property int offset: zoneData && zoneData.Offset !== undefined ? zoneData.Offset : -local.getTimezoneOffset() * 60
    readonly property string city: {
        const id = zone.length > 0 ? zone : (zoneData && zoneData.Timezone ? String(zoneData.Timezone) : "");
        const name = id.length > 0 ? DigitalClock.TimeZonesI18n.i18nCity(id) : "";
        return name.length > 0 ? name : (zoneData && zoneData["Timezone City"] ? String(zoneData["Timezone City"]) : "");
    }
    property date local: new Date()
    readonly property date now: new Date(local.getTime() + (offset + local.getTimezoneOffset() * 60) * 1000)
    readonly property bool night: now.getHours() < 6 || now.getHours() >= 18

    toolTipMainText: city
    toolTipSubText: Qt.locale().toString(now, Locale.LongFormat)

    P5Support.DataSource {
        id: time
        engine: "time"
        connectedSources: [root.source]
        interval: 600000
    }

    Timer {
        interval: 1000 * (60 - root.local.getSeconds())
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.local = new Date()
    }

    Timer {
        running: !Plasmoid.configuration.placed
        interval: 2000
        onTriggered: Plasmoid.configuration.placed = true
    }

    Timer {
        id: askCity
        interval: 900
        onTriggered: {
            const action = Plasmoid.internalAction("configure");
            if (action) {
                action.enabled = true;
                action.trigger();
            }
        }
    }

    Component.onCompleted: {
        if (!Plasmoid.configuration.placed && root.zone.length === 0) {
            askCity.start();
        }
    }

    fullRepresentation: Item {
        LiftHandler {}

        Layout.preferredWidth: 262
        Layout.preferredHeight: 190
        Layout.minimumWidth: 80
        Layout.minimumHeight: 80
        Layout.maximumWidth: root.inPanel ? Layout.preferredWidth : Infinity
        Layout.maximumHeight: root.inPanel ? Layout.preferredHeight : Infinity

        ClockFace {
            anchors.fill: parent
            style: "world"
            now: root.now
            city: root.city
            night: root.night
        }
    }
}
