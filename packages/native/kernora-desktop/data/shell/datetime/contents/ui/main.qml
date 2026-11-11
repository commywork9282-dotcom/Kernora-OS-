/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kernora.bartint
import "m3"

PlasmoidItem {
    id: root

    property date now: new Date()
    readonly property bool clear: Plasmoid.location === PlasmaCore.Types.TopEdge
        && !(Plasmoid.containmentDisplayHints & PlasmaCore.Types.ContainmentPrefersOpaqueBackground)
    readonly property color ink: expanded ? M3.primaryContent : clear ? BarTint.ink(Screen.name, "left") : M3.surfaceContent
    readonly property string timeFormat: Qt.locale().timeFormat(Locale.ShortFormat)
        .replace(/[.:]?s+/g, "").replace(/\s+t$/, "").trim()
    readonly property bool dayFirst: {
        const pattern = Qt.locale().dateFormat(Locale.ShortFormat);
        return pattern.indexOf("d") >= 0 && pattern.indexOf("d") < pattern.indexOf("M");
    }
    readonly property string timeText: {
        let text = Qt.formatTime(now, timeFormat);
        for (const marker of [Qt.locale().amText, Qt.locale().pmText]) {
            const at = marker ? text.toLowerCase().indexOf(marker.toLowerCase()) : -1;
            if (at >= 0) {
                text = text.slice(0, at) + text.slice(at + marker.length);
            }
        }
        return text.replace(/\s+/g, " ").trim();
    }
    readonly property string dateText: now.toLocaleDateString(Qt.locale(), dayFirst ? "ddd, d MMM" : "ddd, MMM d")

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    Plasmoid.title: i18n("Time and Date")
    toolTipMainText: now.toLocaleDateString(Qt.locale(), Locale.LongFormat)
    toolTipSubText: ""

    preferredRepresentation: compactRepresentation

    Timer {
        interval: 60000 - (Date.now() % 60000) + 50
        running: true
        repeat: true
        onTriggered: {
            root.now = new Date();
            interval = 60000 - (Date.now() % 60000) + 50;
        }
    }

    property int monthOffset: 0

    onExpandedChanged: {
        if (expanded) {
            root.now = new Date();
            root.monthOffset = 0;
        }
    }

    compactRepresentation: Item {
        id: compact

        Layout.minimumWidth: row.implicitWidth + 20
        Layout.preferredWidth: row.implicitWidth + 20
        Layout.maximumWidth: row.implicitWidth + 20
        Layout.fillHeight: true

        Accessible.role: Accessible.Button
        Accessible.name: root.timeText + ", " + root.toolTipMainText

        Rectangle {
            id: pill
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: Math.min(parent.height, 28)
            radius: height / 2
            color: root.expanded ? M3.primary : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: M3.durationMedium2
                    easing.type: Easing.Bezier
                    easing.bezierCurve: M3.easingEmphasized
                }
            }

            MStateLayer {
                radius: pill.radius
                color: root.ink
                hovered: mouse.containsMouse
                pressed: mouse.pressed
                pressPoint: Qt.point(mouse.mouseX, mouse.mouseY - pill.y)
            }
        }

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 8

            MText {
                role: "labelLarge"
                font.weight: Font.Bold
                color: root.ink
                text: root.timeText
            }
            MText {
                role: "labelLarge"
                color: root.ink
                text: root.dateText
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }

    fullRepresentation: CalendarView {
        now: root.now
        monthOffset: root.monthOffset
        onShift: delta => root.monthOffset += delta
        onBackToToday: root.monthOffset = 0
    }
}
