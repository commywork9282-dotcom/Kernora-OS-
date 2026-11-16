/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Shapes
import org.kernora.m3

Item {
    id: face

    property string style: "current"
    property bool ready: true
    property string message
    property real temperature
    property real feelsLike
    property real high
    property real low
    property string kind: "clear"
    property bool day: true
    property string city
    property string condition
    property var hours: []
    property var days: []
    property string feelsText
    property string sourceText

    readonly property bool dark: M3.dark
    readonly property color surface: dark ? M3.accent1_800 : M3.accent1_50
    readonly property color panel: dark ? Qt.tint(surface, "#1affffff") : M3.accent1_100
    readonly property color ink: dark ? M3.neutral2_100 : M3.neutral1_900

    readonly property real wide: width / Math.max(1, height)
    readonly property bool stadium: wide >= 1.3
    readonly property real s: Math.min(0.5, width / 766)
    readonly property bool tall: height >= 741 * s

    function degrees(value: real): string {
        return Math.round(value) + "°";
    }

    FontMetrics {
        id: metrics
        font.family: M3.typeface
        font.pixelSize: 200
    }

    readonly property real digitRatio: Math.max(0.5, metrics.tightBoundingRect("1").height / 200)
    readonly property real capRatio: Math.max(0.5, metrics.tightBoundingRect("H").height / 200)

    component Label: Text {
        property Item host
        property real cap
        property real base
        property bool digits: false

        y: host ? base - baselineOffset : 0
        color: host ? host.ink : "white"
        font.family: M3.typeface
        font.pixelSize: host ? Math.max(1, Math.round(cap / (digits ? host.digitRatio : host.capRatio))) : 1
        textFormat: Text.PlainText
        maximumLineCount: 1
        elide: Text.ElideRight
    }

    component Panel: Rectangle {
        property Item host
        property bool first: true
        property bool last: true
        readonly property real big: host ? 22 : 0
        readonly property real small: host ? 5 : 0

        color: host ? host.panel : "transparent"
        topLeftRadius: first ? big : small
        topRightRadius: first ? big : small
        bottomLeftRadius: last ? big : small
        bottomRightRadius: last ? big : small
        antialiasing: true
    }

    Loader {
        anchors.fill: parent
        active: face.style === "current"
        sourceComponent: face.stadium ? stadiumComponent : capsuleComponent
    }

    Loader {
        anchors.fill: parent
        active: face.style === "forecast"
        sourceComponent: forecastComponent
    }

    Component {
        id: capsuleComponent

        Item {
            id: capsule

            readonly property real side: Math.min(width, height)
            readonly property real r: side * 0.4293

            Shape {
                anchors.centerIn: parent
                width: capsule.side
                height: capsule.side
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    readonly property real r: capsule.r
                    readonly property real n: capsule.r / Math.SQRT2
                    readonly property real lo: capsule.side - capsule.r

                    strokeWidth: -1
                    strokeColor: "transparent"
                    fillColor: face.surface
                    startX: r + n
                    startY: lo + n
                    PathLine {
                        x: capsule.side - capsule.r + capsule.r / Math.SQRT2
                        y: capsule.r + capsule.r / Math.SQRT2
                    }
                    PathArc {
                        x: capsule.side - capsule.r - capsule.r / Math.SQRT2
                        y: capsule.r - capsule.r / Math.SQRT2
                        radiusX: capsule.r
                        radiusY: capsule.r
                        direction: PathArc.Counterclockwise
                    }
                    PathLine {
                        x: capsule.r - capsule.r / Math.SQRT2
                        y: capsule.side - capsule.r - capsule.r / Math.SQRT2
                    }
                    PathArc {
                        x: capsule.r + capsule.r / Math.SQRT2
                        y: capsule.side - capsule.r + capsule.r / Math.SQRT2
                        radiusX: capsule.r
                        radiusY: capsule.r
                        direction: PathArc.Counterclockwise
                    }
                }
            }

            Item {
                anchors.centerIn: parent
                width: capsule.side
                height: capsule.side
                visible: face.ready

                Label {
                    host: face
                    digits: true
                    cap: capsule.side * 0.226
                    base: capsule.side * 0.445
                    x: capsule.side * 0.595 - width / 2
                    text: face.degrees(face.temperature)
                }

                WeatherGlyph {
                    x: capsule.side * (0.32 - 0.1415)
                    y: capsule.side * (0.684 - 0.1415)
                    width: capsule.side * 0.283
                    height: width
                    kind: face.kind
                    day: face.day
                }
            }

            Label {
                host: face
                visible: !face.ready
                anchors.horizontalCenter: parent.horizontalCenter
                width: capsule.side * 0.6
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                maximumLineCount: 3
                cap: capsule.side * 0.05
                base: parent.height / 2
                text: face.message
            }
        }
    }

    Component {
        id: stadiumComponent

        Item {
            id: pill

            readonly property real u: height / 580
            readonly property real startX: (width - 560 * u) / 2

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: face.surface
                antialiasing: true
            }

            Item {
                anchors.fill: parent
                visible: face.ready

                WeatherGlyph {
                    x: pill.startX
                    y: 180 * pill.u
                    width: 230 * pill.u
                    height: width
                    kind: face.kind
                    day: face.day
                }

                Label {
                    host: face
                    digits: true
                    x: pill.startX + 287 * pill.u
                    cap: 137 * pill.u
                    base: 307 * pill.u
                    text: face.degrees(face.temperature)
                }

                Label {
                    host: face
                    x: pill.startX + 305 * pill.u
                    cap: 36 * pill.u
                    base: 416 * pill.u
                    text: face.degrees(face.high) + " · " + face.degrees(face.low)
                }

                Label {
                    host: face
                    anchors.horizontalCenter: parent.horizontalCenter
                    cap: 13 * pill.u
                    base: 558 * pill.u
                    text: face.sourceText
                }
            }

            Label {
                host: face
                visible: !face.ready
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width * 0.7
                horizontalAlignment: Text.AlignHCenter
                cap: 36 * pill.u
                base: parent.height / 2
                text: face.message
            }
        }
    }

    Component {
        id: forecastComponent

        Item {
            id: card

            readonly property real s: face.s
            readonly property real pad: 42 * s
            readonly property real footTop: height - 41 * s
            readonly property real panelBottom: footTop - 32 * s
            readonly property real hourlyHeight: 272 * s
            readonly property real rowHeight: 124 * s
            readonly property real rowRoom: height - (396 + 272 + 73) * s
            readonly property int dayRows: face.tall && rowRoom >= 151 * s
                ? Math.min(5, face.days.length, 1 + Math.floor((rowRoom - 151 * s) / (130 * s)))
                : 0
            readonly property real panelTop: face.tall
                ? panelBottom - (dayRows > 0 ? dayRows * rowHeight + (dayRows - 1) * 6 * s + 27 * s : 0) - hourlyHeight
                : 0
            readonly property real blockTop: face.tall ? 93 * s + Math.max(0, (panelTop - 93 * s - 242 * s) / 2) : 119 * s
            readonly property real tempRight: width - (face.tall ? 45 : 42) * s
            readonly property int compactColumns: Math.max(0, Math.min(4, face.hours.length,
                                                                       Math.floor((tempRight - 540 * s) / (173 * s)) + 1))

            Rectangle {
                anchors.fill: parent
                radius: 28
                color: face.surface
                antialiasing: true
            }

            Label {
                host: face
                x: card.pad
                width: (face.tall ? card.width - 2 * card.pad : card.width * 0.55)
                cap: 33 * card.s
                base: 83 * card.s
                font.weight: Font.Medium
                text: face.city
            }

            Item {
                anchors.fill: parent
                visible: face.ready

                WeatherGlyph {
                    x: 44 * card.s
                    y: card.blockTop
                    width: 75 * card.s
                    height: width
                    kind: face.kind
                    day: face.day
                }

                Label {
                    host: face
                    x: 162 * card.s
                    width: Math.max(0, card.tempRight - 255 * card.s - x)
                    cap: 35 * card.s
                    base: card.blockTop + 54 * card.s
                    text: face.condition
                }

                Label {
                    host: face
                    x: 46 * card.s
                    width: Math.max(0, card.tempRight - 255 * card.s - x)
                    cap: 36 * card.s
                    base: card.blockTop + 150 * card.s
                    text: face.feelsText
                }

                Label {
                    host: face
                    x: 44 * card.s
                    cap: 36 * card.s
                    base: card.blockTop + 236 * card.s
                    text: face.degrees(face.high) + " · " + face.degrees(face.low)
                }

                Label {
                    host: face
                    digits: true
                    x: card.tempRight - width
                    cap: 124 * card.s
                    base: face.tall ? card.blockTop + 182 * card.s : 168 * card.s
                    text: face.degrees(face.temperature)
                }

                Panel {
                    id: hourly

                    host: face
                    visible: face.tall
                    x: card.pad
                    y: card.panelTop
                    width: card.width - 2 * card.pad
                    height: card.hourlyHeight

                    readonly property int columns: Math.max(1, Math.min(6, face.hours.length,
                                                                        Math.floor((width - 62 * card.s) / (137 * card.s))))
                    readonly property real column: (width - 62 * card.s) / columns

                    Repeater {
                        model: face.tall ? face.hours.slice(0, hourly.columns) : []

                        delegate: Item {
                            required property var modelData
                            required property int index

                            x: 31 * card.s + index * hourly.column
                            width: hourly.column
                            height: hourly.height

                            Label {
                                host: face
                                anchors.horizontalCenter: parent.horizontalCenter
                                cap: 22 * card.s
                                base: 62 * card.s
                                text: face.degrees(modelData.temperature)
                            }
                            WeatherGlyph {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 108 * card.s
                                width: 57 * card.s
                                height: width
                                kind: modelData.kind
                                day: modelData.day
                            }
                            Label {
                                host: face
                                anchors.horizontalCenter: parent.horizontalCenter
                                cap: 21 * card.s
                                base: 231 * card.s
                                text: modelData.label
                            }
                        }
                    }
                }

                Repeater {
                    model: card.dayRows

                    delegate: Panel {
                        id: dayRow

                        required property int index
                        readonly property var entry: face.days[index]

                        host: face
                        first: index === 0
                        last: index === card.dayRows - 1
                        x: card.pad
                        y: card.panelTop + card.hourlyHeight + 27 * card.s + index * (card.rowHeight + 6 * card.s)
                        width: card.width - 2 * card.pad
                        height: card.rowHeight

                        Label {
                            host: face
                            x: 44 * card.s
                            width: parent.width * 0.5
                            cap: 25 * card.s
                            base: 74 * card.s
                            text: dayRow.entry ? dayRow.entry.label : ""
                        }
                        Label {
                            host: face
                            x: parent.width - 139 * card.s - width
                            cap: 25 * card.s
                            base: 74 * card.s
                            text: dayRow.entry ? face.degrees(dayRow.entry.high) + " " + face.degrees(dayRow.entry.low) : ""
                        }
                        WeatherGlyph {
                            x: parent.width - 46 * card.s - width
                            anchors.verticalCenter: parent.verticalCenter
                            width: 56 * card.s
                            height: width
                            kind: dayRow.entry ? dayRow.entry.kind : "clear"
                        }
                    }
                }

                Repeater {
                    model: face.tall ? [] : face.hours.slice(0, card.compactColumns)

                    delegate: Item {
                        required property var modelData
                        required property int index

                        x: card.tempRight - 85 * card.s - (card.compactColumns - 1 - index) * 173 * card.s - width / 2
                        width: 150 * card.s
                        height: card.height

                        Label {
                            host: face
                            anchors.horizontalCenter: parent.horizontalCenter
                            cap: 25 * card.s
                            base: card.height - 219 * card.s
                            text: face.degrees(modelData.temperature)
                        }
                        WeatherGlyph {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: card.height - 174 * card.s
                            width: 55 * card.s
                            height: width
                            kind: modelData.kind
                            day: modelData.day
                        }
                        Label {
                            host: face
                            anchors.horizontalCenter: parent.horizontalCenter
                            cap: 21 * card.s
                            base: card.height - 56 * card.s
                            text: modelData.label
                        }
                    }
                }

                Label {
                    host: face
                    x: face.tall ? (card.width - width) / 2 : card.pad
                    cap: 13 * card.s
                    base: face.tall ? card.footTop + 13 * card.s : card.height - 55 * card.s
                    text: face.sourceText
                }
            }

            Label {
                host: face
                visible: !face.ready
                x: card.pad
                width: card.width - 2 * card.pad
                wrapMode: Text.Wrap
                maximumLineCount: 3
                cap: 30 * card.s
                base: card.height / 2
                text: face.message
            }
        }
    }
}
