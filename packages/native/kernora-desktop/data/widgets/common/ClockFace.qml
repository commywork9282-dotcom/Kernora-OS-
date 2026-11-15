/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Shapes
import org.kernora.m3

Item {
    id: face

    property string style: "analog"
    property date now: new Date()
    property bool twelveHours: Qt.locale().timeFormat(Locale.ShortFormat).toLowerCase().indexOf("ap") >= 0
    property string city
    property bool night: false

    readonly property bool dark: M3.dark
    readonly property real ratio: style === "digital" ? 342 / 248 : style === "stacked" ? 270 / 371 : style === "analog" ? 1 : 0
    readonly property real boxWidth: ratio > 0 ? Math.min(width, height * ratio) : width
    readonly property real boxHeight: ratio > 0 ? boxWidth / ratio : height
    readonly property real unit: style === "world" ? Math.min(boxWidth, boxHeight) : boxHeight
    readonly property real textTop: (boxHeight - unit) / 2

    readonly property color surface: style === "world" && night
        ? (dark ? M3.accent1_800 : M3.accent1_200)
        : (dark ? M3.accent2_800 : M3.accent1_50)
    readonly property color label: dark ? M3.neutral1_50 : M3.neutral1_900
    readonly property color accent: dark ? M3.accent1_100 : M3.accent1_600

    readonly property int hour: now.getHours()
    readonly property int shownHour: twelveHours ? (hour + 11) % 12 + 1 : hour

    function timeText(): string {
        const minutes = String(face.now.getMinutes()).padStart(2, "0");
        return (face.twelveHours ? String(face.shownHour) : String(face.hour).padStart(2, "0")) + ":" + minutes;
    }

    function dateText(): string {
        const comma = ["ru", "uk", "be", "kk"].indexOf(Qt.locale().name.split("_")[0]) >= 0;
        const text = Qt.locale().toString(face.now, comma ? "ddd, d" : "ddd d");
        return text.charAt(0).toUpperCase() + text.slice(1);
    }

    function dayText(): string {
        const day = Qt.locale().toString(face.now, "ddd");
        const capital = day.charAt(0).toUpperCase() + day.slice(1);
        return face.twelveHours ? (face.hour < 12 ? Qt.locale().amText : Qt.locale().pmText) + " / " + capital : capital;
    }

    FontMetrics {
        id: metrics
        font.family: M3.typeface
        font.pixelSize: 200
    }

    readonly property real digitRatio: Math.max(0.5, metrics.tightBoundingRect("1").height / 200)
    readonly property real capRatio: Math.max(0.5, metrics.tightBoundingRect("H").height / 200)

    component Line: Text {
        property Item host
        property real capHeight
        property real baselineAt
        property bool digits: false

        x: host ? (host.boxWidth - width) / 2 : 0
        y: host ? host.textTop + baselineAt - baselineOffset : 0
        width: host ? host.boxWidth * 0.9 : 0
        horizontalAlignment: Text.AlignHCenter
        font.family: M3.typeface
        font.pixelSize: host ? Math.max(1, Math.round(capHeight / (digits ? host.digitRatio : host.capRatio))) : 1
        font.weight: Font.Normal
        fontSizeMode: Text.HorizontalFit
        minimumPixelSize: 6
        textFormat: Text.PlainText
        maximumLineCount: 1
    }

    component Hand: Item {
        id: hand

        property real angle
        property real reach
        property real radius
        property color color
        readonly property real thickness: radius * 0.166

        anchors.centerIn: parent
        width: 0
        height: 0
        rotation: angle

        Rectangle {
            x: -hand.thickness / 2
            y: -hand.radius * hand.reach
            width: hand.thickness
            height: hand.radius * hand.reach + hand.thickness / 2
            radius: hand.thickness / 2
            color: hand.color
            antialiasing: true
        }
    }

    Item {
        id: box

        anchors.centerIn: parent
        width: face.boxWidth
        height: face.boxHeight

        Rectangle {
            anchors.fill: parent
            visible: face.style !== "analog"
            radius: face.style === "world" ? Math.min(width, height) / 6 : Math.min(width, height) / 2
            color: face.surface
            antialiasing: true
        }

        Loader {
            anchors.fill: parent
            active: face.style === "analog"
            sourceComponent: analog
        }

        Loader {
            anchors.fill: parent
            active: face.style === "digital"
            sourceComponent: Item {
                Line {
                    host: face
                    capHeight: face.unit * 0.0645
                    baselineAt: face.unit * 0.218
                    text: face.dateText()
                    color: face.label
                }
                Line {
                    host: face
                    digits: true
                    capHeight: face.unit * 0.3226
                    baselineAt: face.unit * 0.649
                    text: face.timeText()
                    color: face.accent
                }
            }
        }

        Loader {
            anchors.fill: parent
            active: face.style === "stacked"
            sourceComponent: Item {
                Line {
                    host: face
                    capHeight: face.unit * 0.0377
                    baselineAt: face.unit * 0.1617
                    text: face.dateText()
                    color: face.label
                }
                Line {
                    host: face
                    digits: true
                    capHeight: face.unit * 0.2264
                    baselineAt: face.unit * 0.4609
                    text: String(face.shownHour).padStart(2, "0")
                    color: face.dark ? M3.accent2_200 : M3.accent2_600
                }
                Line {
                    host: face
                    digits: true
                    capHeight: face.unit * 0.2264
                    baselineAt: face.unit * 0.7493
                    text: String(face.now.getMinutes()).padStart(2, "0")
                    color: face.accent
                }
            }
        }

        Loader {
            anchors.fill: parent
            active: face.style === "world"
            sourceComponent: Item {
                Line {
                    host: face
                    capHeight: face.unit * 0.0523
                    baselineAt: face.unit * 0.2369
                    text: face.city
                    color: face.label
                    fontSizeMode: Text.FixedSize
                    elide: Text.ElideRight
                }
                Line {
                    host: face
                    digits: true
                    capHeight: face.unit * 0.2334
                    baselineAt: face.unit * 0.6063
                    text: face.timeText()
                    color: face.accent
                }
                Line {
                    host: face
                    capHeight: face.unit * 0.0523
                    baselineAt: face.unit * 0.8084
                    text: face.dayText()
                    color: face.label
                }
            }
        }
    }

    Component {
        id: analog

        Item {
            id: dial

            readonly property real radius: width / 2
            readonly property real seconds: face.now.getSeconds()
            readonly property real minutes: face.now.getMinutes() + seconds / 60
            readonly property real hours: face.now.getHours() % 12 + minutes / 60

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: face.dark ? M3.accent2_800 : M3.accent1_50
                    strokeWidth: -1
                    strokeColor: "transparent"

                    PathPolyline {
                        path: {
                            const points = [];
                            const r = dial.radius;
                            const steps = 360;
                            for (let i = 0; i <= steps; ++i) {
                                const angle = i / steps * 2 * Math.PI;
                                const reach = r * (0.965 + 0.033 * Math.cos(12 * angle) + 0.002 * Math.cos(24 * angle));
                                points.push(Qt.point(r + reach * Math.sin(angle), r - reach * Math.cos(angle)));
                            }
                            return points;
                        }
                    }
                }
            }

            Hand {
                angle: dial.hours * 30
                reach: 0.489
                radius: dial.radius
                color: face.dark ? M3.accent2_200 : M3.accent2_700
            }

            Hand {
                angle: dial.minutes * 6
                reach: 0.681
                radius: dial.radius
                color: face.dark ? M3.accent1_100 : M3.accent1_500
            }

            Item {
                anchors.centerIn: parent
                width: 0
                height: 0
                rotation: dial.seconds * 6

                Rectangle {
                    readonly property real size: dial.radius * 0.19
                    x: -size / 2
                    y: -dial.radius * 0.811 - size / 2
                    width: size
                    height: size
                    radius: size / 2
                    color: face.dark ? M3.accent3_100 : M3.accent3_500
                    antialiasing: true
                }
            }
        }
    }
}
