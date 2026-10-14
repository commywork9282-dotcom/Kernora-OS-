/*
    SPDX-FileCopyrightText: 2019 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2019 David Edmundson <davidedmundson@kde.org>
    SPDX-FileCopyrightText: 2019 Arjen Hiemstra <ahiemstra@heimr.nl>
    SPDX-FileCopyrightText: 2026 Kernora Developers

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick 2.0
import QtQuick.Layouts 1.1
import QtQuick.Window 2.12

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid 2.0
import org.kde.kirigami 2.20 as Kirigami

import org.kde.ksysguard.sensors 1.0 as Sensors


PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.ConfigurableBackground

    // Determine the right value to use for representation switching
    function switchSizeFromSize(formFactor, compactMax, fullMin) {
        // If we are planar (aka on the desktop), do not do any switching
        if (Plasmoid.formFactor === PlasmaCore.Types.Planar) {
            return -1
        }

        // If we are in a form factor where we can extend freely one way, don't
        // use that for determining switching.
        if (Plasmoid.formFactor === formFactor) {
            // 0 or less is considered as "no switching" so return the smallest
            // possible still valid value.
            return 1
        }

        // Layout.maximumWidth will return Infinity if it isn't set, so handle that.
        if (!Number.isFinite(compactMax)) {
            // This is the default maximum size for compact reps, with 1 subtracted
            // to ensure we switch if the maximum is reached.
            compactMax = Kirigami.Units.iconSizes.enormous - 1
        }

        // Layout.minimumWidth will return -1 if it is not set, handle that.
        if (fullMin <= 0) {
            fullMin = Kirigami.Units.iconSizes.enormous - 1
        }

        // Use the larger of the two sizes to ensure we switch when the compact
        // rep reaches its maximum but we don't try to cram in a full rep that
        // won't actually fit.
        return Math.max(compactMax, fullMin)
    }

    switchWidth: switchSizeFromSize(PlasmaCore.Types.Horizontal, compactRepresentationItem?.Layout.maximumWidth ?? Infinity, fullRepresentationItem?.Layout.minimumWidth ?? -1)
    switchHeight: switchSizeFromSize(PlasmaCore.Types.Vertical, compactRepresentationItem?.Layout.maximumHeight ?? Infinity, fullRepresentationItem?.Layout.minimumHeight ?? -1)

    preferredRepresentation: Plasmoid.formFactor === PlasmaCore.Types.Planar ? fullRepresentation : null

    Plasmoid.title: Plasmoid.faceController.title || i18n("System Monitor")
    toolTipSubText: totalSensor.sensorId ? i18nc("Sensor name: value", "%1: %2", totalSensor.name, totalSensor.formattedValue) : ""

    compactRepresentation: CompactRepresentation {
    }
    fullRepresentation: FullRepresentation {
    }

    Plasmoid.configurationRequired: Plasmoid.faceController.highPrioritySensorIds.length == 0 && Plasmoid.faceController.lowPrioritySensorIds.length == 0 && Plasmoid.faceController.totalSensors.length == 0

    Sensors.Sensor {
        id: totalSensor
        sensorId: Plasmoid.faceController.totalSensors[0] || ""
        updateRateLimit: Plasmoid.faceController.updateRateLimit
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton
        onClicked: Plasmoid.openSystemMonitor()
    }

    readonly property color kernoraAccent: Kirigami.Theme.highlightColor
    onKernoraAccentChanged: Qt.callLater(root.kernoraRecolor)
    Component.onCompleted: Qt.callLater(root.kernoraRecolor)

    Connections {
        target: Plasmoid.faceController
        function onHighPrioritySensorIdsChanged() {
            Qt.callLater(root.kernoraRecolor)
        }
    }

    function kernoraPalette(base, count) {
        const colors = []
        for (let i = 0; i < count; ++i) {
            let hue = Math.max(0, base.hsvHue) + i / count
            hue -= Math.floor(hue)
            colors.push(Qt.hsva(hue, base.hsvSaturation, base.hsvValue, base.a))
        }
        return colors
    }

    function kernoraClose(first, second) {
        const a = Qt.color(first)
        const b = Qt.color(second)
        return Math.abs(a.r - b.r) < 0.012 && Math.abs(a.g - b.g) < 0.012 && Math.abs(a.b - b.b) < 0.012
    }

    function kernoraRecolor() {
        const controller = Plasmoid.faceController
        if (!controller) {
            return
        }
        const ids = controller.highPrioritySensorIds
        const recorded = Plasmoid.configuration.kernoraColorBase
        const accent = root.kernoraAccent
        if (ids.length === 0 || (recorded.length > 0 && kernoraClose(recorded, accent))) {
            return
        }
        const saved = controller.sensorColors
        const reference = recorded.length > 0 ? recorded : saved[ids[0]]
        if (!reference) {
            Plasmoid.configuration.kernoraColorBase = accent.toString()
            return
        }
        const previous = kernoraPalette(Qt.color(reference), ids.length)
        const next = kernoraPalette(accent, ids.length)
        const updated = Object.assign({}, saved)
        let matched = 0
        for (let i = 0; i < ids.length; ++i) {
            if (saved[ids[i]] && kernoraClose(saved[ids[i]], previous[i])) {
                updated[ids[i]] = next[i]
                matched += 1
            }
        }
        if (matched > 0 && (recorded.length > 0 || matched === ids.length)) {
            controller.sensorColors = updated
        }
        Plasmoid.configuration.kernoraColorBase = accent.toString()
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18nc("@action", "Open System Monitor…")
            icon.name: "utilities-system-monitor"
            onTriggered: Plasmoid.openSystemMonitor()
        }
    ]
}
