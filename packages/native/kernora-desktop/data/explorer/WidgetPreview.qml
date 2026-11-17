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
        running: root.visible && (root.kind.indexOf("clock") === 0 || root.kind === "glance" || root.kind === "calendar")
        repeat: true
        onTriggered: root.now = new Date()
    }

    Loader {
        anchors.centerIn: parent
        sourceComponent: {
            switch (root.kind) {
            case "clock":
            case "clock-analog":
            case "clock-digital":
            case "clock-stacked":
            case "worldclock":
                return clock;
            case "stopwatch":
                return stopwatch;
            case "timer":
                return timers;
            case "glance":
                return glance;
            case "weather":
            case "weather-current":
            case "weather-forecast":
                return weather;
            case "cputemperature":
                return cpuTemperature;
            case "battery":
                return battery;
            case "calendar":
                return calendar;
            case "media":
                return media;
            case "photo":
                return photo;
            case "photo-cookie9":
            case "photo-sunny":
            case "photo-flower":
            case "photo-circle":
            case "photo-square":
            case "photo-pill":
            case "photo-fill":
                return shapedPhoto;
            case "note":
                return note;
            default:
                return generic;
            }
        }
    }

    Component {
        id: cpuTemperature
        Item {
            width: 168
            height: 124
            TemperatureCard {
                anchors.centerIn: parent
                width: 280
                height: 208
                scale: 0.58
                degrees: 48
                peak: 56
                heading: i18nd("plasma_applet_org.kernora.widget.cputemperature", "CPU temperature")
                caption: i18nd("plasma_applet_org.kernora.widget.cputemperature", "Preview")
                peakText: i18nd("plasma_applet_org.kernora.widget.cputemperature", "Peak")
                history: Array.from({length: 60}, (_, i) => 46 + 6 * Math.sin(i * 0.22) + 3 * Math.sin(i * 0.7))
            }
        }
    }

    Component {
        id: clock

        ClockFace {
            width: root.width
            height: root.height
            style: root.kind === "worldclock" ? "world" : root.kind.indexOf("clock-") === 0 ? root.kind.substring(6) : "stacked"
            now: root.kind === "worldclock" ? new Date(2026, 0, 7, 10, 30) : root.now
            twelveHours: root.twelveHours
            city: i18nd("kernora-ui", "London")
        }
    }

    Component {
        id: stopwatch

        StopwatchFace {
            width: root.width
            height: root.height
            elapsed: 302000
            running: true
            laps: 1
            interactive: false
            lapText: i18nd("kernora-ui", "Lap %1", 2)
        }
    }

    Component {
        id: timers

        TimerFace {
            width: 272
            height: 284
            scale: Math.min(root.width / width, root.height / height)
            interactive: false
            title: i18nd("kernora-ui", "Timers")
            items: [10, 1, 5].map(minutes => ({
                label: i18ndc("kernora-ui", "@label timer length", "%1m", minutes),
                state: "idle",
                remaining: minutes * 60000,
                total: minutes * 60000
            }))
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

        WeatherFace {
            width: root.width
            height: root.height
            style: root.kind === "weather-forecast" ? "forecast" : "current"
            temperature: 24
            feelsLike: 25
            high: 26
            low: 17
            kind: "mostly"
            city: i18nd("kernora-ui", "London")
            condition: i18nd("kernora-ui", "Mostly sunny")
            feelsText: i18nd("kernora-ui", "Feels like %1", "25°")
            sourceText: i18nd("kernora-ui", "Source: Open-Meteo")
            hours: [i18nd("kernora-ui", "Now"), 13, 14, 15, 16, 17].map((label, index) => ({
                label: index === 0 ? label : (root.twelveHours ? (label - 12) + " " + Qt.locale().pmText : label + ":00"),
                temperature: [24, 25, 26, 26, 25, 23][index],
                kind: index < 2 ? "mostly" : "clear",
                day: true
            }))
            days: [1, 2, 3, 4, 5].map(offset => {
                const date = new Date();
                date.setDate(date.getDate() + offset);
                const name = Qt.locale().standaloneDayName(date.getDay(), Locale.LongFormat);
                return {
                    label: name.charAt(0).toUpperCase() + name.slice(1),
                    high: [26, 24, 22, 23, 25][offset - 1],
                    low: [17, 16, 14, 15, 16][offset - 1],
                    kind: ["clear", "partly", "rain", "cloudy", "mostly"][offset - 1]
                };
            })
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
        id: shapedPhoto

        Item {
            readonly property string shape: root.kind.substring(6)

            width: root.width
            height: root.height

            MaterialShape {
                anchors.fill: parent
                visible: !sample.ready && parent.shape !== "fill"
                shape: parent.shape
                color: M3.tertiaryContainer
            }

            Rectangle {
                anchors.fill: parent
                visible: !sample.ready && parent.shape === "fill"
                radius: 28 * 0.6
                color: M3.tertiaryContainer
            }

            ShapedPhoto {
                id: sample
                anchors.fill: parent
                shape: parent.shape
                radius: 28 * 0.6
                source: "file:///usr/share/wallpapers/kernora-landscapes-snowy-peaks/contents/images/3840x2160.jpg"
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
