/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.private.battery
import "m3"

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    switchWidth: Plasmoid.configuration.placed ? 0 : 239
    switchHeight: Plasmoid.configuration.placed ? 0 : 149

    Timer {
        running: !Plasmoid.configuration.placed
        interval: 2000
        onTriggered: Plasmoid.configuration.placed = true
    }

    toolTipMainText: i18n("Batteries")
    toolTipSubText: ""

    BatteryControlModel {
        id: batteries
    }

    function deviceIcon(type: int): string {
        switch (type) {
        case 3:
            return "computer-laptop";
        case 4:
            return "input-mouse";
        case 5:
        case 6:
            return "input-keyboard";
        case 8:
            return "smartphone";
        case 13:
            return "audio-headphones";
        case 14:
            return "audio-headset";
        case 15:
            return "input-touchpad";
        case 11:
            return "bluetooth";
        default:
            return "battery-full";
        }
    }

    fullRepresentation: WidgetSurface {
        id: card
        Layout.preferredWidth: Math.max(200, Math.min(4, Math.max(1, ringRow.count)) * 104 + 40)
        Layout.preferredHeight: 150
        Layout.minimumWidth: 140
        Layout.minimumHeight: 110

        readonly property real ring: Math.min(height - 56, (width - 32) / Math.max(1, ringRow.count) - 16)

        RowLayout {
            anchors.centerIn: parent
            spacing: 16
            visible: ringRow.count > 0

            Repeater {
                id: ringRow
                model: batteries
                delegate: ColumnLayout {
                    id: battery
                    required property var model
                    readonly property int percent: model.Percent
                    readonly property int type: model.Type
                    readonly property bool charging: model.ChargeState === 1
                    spacing: 6

                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: card.ring
                        implicitHeight: card.ring

                        Shape {
                            id: rings
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer
                            readonly property real stroke: Math.max(5, card.ring * 0.1)

                            ShapePath {
                                strokeColor: M3.surfaceContainerHighest
                                strokeWidth: rings.stroke
                                fillColor: "transparent"
                                capStyle: ShapePath.RoundCap
                                PathAngleArc {
                                    centerX: card.ring / 2
                                    centerY: card.ring / 2
                                    radiusX: (card.ring - rings.stroke) / 2
                                    radiusY: radiusX
                                    startAngle: 0
                                    sweepAngle: 360
                                }
                            }
                            ShapePath {
                                strokeColor: battery.percent <= 15 && !battery.charging ? M3.error : M3.primary
                                strokeWidth: rings.stroke
                                fillColor: "transparent"
                                capStyle: ShapePath.RoundCap
                                PathAngleArc {
                                    centerX: card.ring / 2
                                    centerY: card.ring / 2
                                    radiusX: (card.ring - rings.stroke) / 2
                                    radiusY: radiusX
                                    startAngle: -90
                                    sweepAngle: Math.max(1, battery.percent) * 3.6
                                }
                            }
                        }
                        MIcon {
                            anchors.centerIn: parent
                            size: Math.round(card.ring * 0.36)
                            source: root.deviceIcon(battery.type)
                            color: M3.surfaceContent
                        }
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 2
                        MIcon {
                            visible: battery.charging
                            size: 16
                            source: "battery-charging"
                            color: M3.primary
                        }
                        MText {
                            role: "labelLarge"
                            text: i18n("%1%", battery.percent)
                            color: M3.surfaceContent
                        }
                    }
                }
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            visible: ringRow.count === 0
            spacing: 8

            MIcon {
                Layout.alignment: Qt.AlignHCenter
                size: 36
                source: "computer"
                color: M3.primary
            }
            MText {
                Layout.alignment: Qt.AlignHCenter
                role: "titleSmall"
                text: i18n("Running on mains power")
            }
        }
    }
}
