/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick
import QtQuick.Shapes
import org.kernora.m3

Item {
    id: root

    property string kind
    property var icon
    property date now: new Date()
    readonly property bool twelveHours: Qt.locale().timeFormat(Locale.ShortFormat).toLowerCase().indexOf("ap") >= 0

    Timer {
        interval: 20000
        running: root.visible && (root.kind === "clock" || root.kind === "glance" || root.kind === "calendar")
        repeat: true
        onTriggered: root.now = new Date()
    }

    Loader {
        anchors.centerIn: parent
        sourceComponent: {
            switch (root.kind) {
            case "clock":
                return clock;
            case "glance":
                return glance;
            case "weather":
                return weather;
            case "battery":
                return battery;
            case "calendar":
                return calendar;
            case "media":
                return media;
            case "photo":
                return photo;
            case "note":
                return note;
            default:
                return generic;
            }
        }
    }

    component Digits: Text {
        color: M3.primary
        font.family: M3.typeface
        font.pixelSize: 44
        font.weight: Font.Medium
        font.letterSpacing: -2
        font.features: { "tnum": 1 }
        anchors.horizontalCenter: parent.horizontalCenter
    }

    Component {
        id: clock

        Column {
            spacing: -12

            Digits {
                text: String(root.twelveHours ? (root.now.getHours() + 11) % 12 + 1 : root.now.getHours()).padStart(2, "0")
            }
            Digits {
                text: String(root.now.getMinutes()).padStart(2, "0")
                color: M3.tertiary
            }
        }
    }

    Component {
        id: glance

        Column {
            spacing: 6

            MText {
                role: "titleMedium"
                text: {
                    const date = Qt.locale().toString(root.now, "ddd, d MMMM");
                    return date.charAt(0).toUpperCase() + date.slice(1);
                }
            }
            Row {
                spacing: 6

                MIcon {
                    size: 18
                    source: "weather-few-clouds"
                    color: M3.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
                MText {
                    role: "bodyMedium"
                    text: "18°"
                    color: M3.surfaceVariantContent
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    Component {
        id: weather

        MaterialShape {
            width: 92
            height: 92
            shape: "sunny"
            color: M3.primaryContainer

            MText {
                anchors.centerIn: parent
                role: "headlineSmall"
                text: "18°"
                color: M3.primaryContainerContent
            }
        }
    }

    Component {
        id: battery

        Row {
            spacing: 10

            Repeater {
                model: [{ value: 0.8, icon: "computer-laptop" }, { value: 0.45, icon: "input-mouse" }]

                delegate: Item {
                    id: ring

                    required property var modelData
                    width: 56
                    height: 56

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            strokeWidth: 5
                            strokeColor: M3.surfaceContainerHighest
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            PathAngleArc {
                                centerX: 28
                                centerY: 28
                                radiusX: 25
                                radiusY: 25
                                startAngle: -90
                                sweepAngle: 360
                            }
                        }
                        ShapePath {
                            strokeWidth: 5
                            strokeColor: M3.primary
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            PathAngleArc {
                                centerX: 28
                                centerY: 28
                                radiusX: 25
                                radiusY: 25
                                startAngle: -90
                                sweepAngle: 360 * ring.modelData.value
                            }
                        }
                    }
                    MIcon {
                        anchors.centerIn: parent
                        size: 22
                        source: ring.modelData.icon
                        color: M3.surfaceContent
                    }
                }
            }
        }
    }

    Component {
        id: calendar

        Column {
            spacing: 6

            MText {
                role: "labelLarge"
                text: {
                    const month = Qt.locale().standaloneMonthName(root.now.getMonth());
                    return month.charAt(0).toUpperCase() + month.slice(1);
                }
            }
            Grid {
                columns: 7
                spacing: 3

                Repeater {
                    model: 14

                    delegate: Rectangle {
                        id: day

                        required property int index
                        readonly property var date: {
                            const start = new Date(root.now);
                            start.setDate(root.now.getDate() - (root.now.getDay() + 6) % 7 + index);
                            return start;
                        }
                        readonly property bool today: date.getDate() === root.now.getDate() && date.getMonth() === root.now.getMonth()

                        width: 18
                        height: 18
                        radius: 9
                        color: today ? M3.primary : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: day.date.getDate()
                            color: day.today ? M3.primaryContent : M3.surfaceContent
                            font.family: M3.typeface
                            font.pixelSize: 10
                            font.features: { "tnum": 1 }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: media

        Rectangle {
            width: 136
            height: 72
            radius: 18
            color: M3.secondaryContainer

            Rectangle {
                id: cover
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 52
                height: 52
                radius: 12
                color: M3.tertiaryContainer

                MIcon {
                    anchors.centerIn: parent
                    size: 24
                    source: "audio-x-generic"
                    color: M3.tertiaryContainerContent
                }
            }
            Shape {
                x: cover.x + cover.width + 10
                y: 22
                width: 42
                height: 8
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: 3
                    strokeColor: M3.secondaryContainerContent
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathSvg {
                        path: "M 1 4 Q 6 0 11 4 T 21 4 T 31 4 T 41 4"
                    }
                }
            }
            Rectangle {
                x: cover.x + cover.width + 18
                y: 38
                width: 26
                height: 26
                radius: 13
                color: M3.primary

                MIcon {
                    anchors.centerIn: parent
                    size: 16
                    source: "media-playback-start"
                    color: M3.primaryContent
                }
            }
        }
    }

    Component {
        id: photo

        MaterialShape {
            width: 96
            height: 96
            shape: "cookie9"
            color: M3.tertiaryContainer

            MIcon {
                anchors.centerIn: parent
                size: 36
                source: "image-x-generic"
                color: M3.tertiaryContainerContent
            }
        }
    }

    Component {
        id: note

        Rectangle {
            width: 104
            height: 84
            radius: 18
            color: M3.tertiaryContainer

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 9

                Repeater {
                    model: [1, 0.8, 0.55]

                    delegate: Rectangle {
                        required property real modelData
                        width: (parent.width) * modelData
                        height: 6
                        radius: 3
                        color: M3.withAlpha(M3.tertiaryContainerContent, 0.5)
                    }
                }
            }
        }
    }

    Component {
        id: generic

        MaterialShape {
            width: 80
            height: 80
            shape: "cookie9"
            color: M3.secondaryContainer

            MIcon {
                anchors.centerIn: parent
                size: 36
                source: root.icon
                color: M3.secondaryContainerContent
            }
        }
    }
}
