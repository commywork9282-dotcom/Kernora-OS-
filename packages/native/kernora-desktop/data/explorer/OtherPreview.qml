/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick
import QtQuick.Shapes
import org.kde.kirigami as Kirigami
import org.kernora.m3

Item {
    id: root

    property var spec
    property var icon
    property date now: new Date()
    readonly property string kind: spec && spec.preview ? spec.preview : "glyph"
    readonly property bool twelveHours: Qt.locale().timeFormat(Locale.ShortFormat).toLowerCase().indexOf("ap") >= 0
    readonly property color dim: M3.withAlpha(M3.surfaceContent, 0.16)

    function container(tone: string): color {
        return tone === "secondary" ? M3.secondaryContainer : tone === "tertiary" ? M3.tertiaryContainer : M3.primaryContainer;
    }

    function onContainer(tone: string): color {
        return tone === "secondary" ? M3.secondaryContainerContent
             : tone === "tertiary" ? M3.tertiaryContainerContent : M3.primaryContainerContent;
    }

    function time(): string {
        const hours = root.twelveHours ? (root.now.getHours() + 11) % 12 + 1 : root.now.getHours();
        return (root.twelveHours ? String(hours) : String(hours).padStart(2, "0")) + ":" + String(root.now.getMinutes()).padStart(2, "0");
    }

    function curve(values: var, w: real, h: real): string {
        const n = values.length;
        const p = values.map((v, i) => [w * i / (n - 1), h - v * h]);
        let d = "M " + p[0][0] + " " + p[0][1];
        for (let i = 0; i < n - 1; ++i) {
            const a = p[Math.max(0, i - 1)];
            const b = p[i];
            const c = p[i + 1];
            const e = p[Math.min(n - 1, i + 2)];
            d += " C " + (b[0] + (c[0] - a[0]) / 6) + " " + (b[1] + (c[1] - a[1]) / 6)
               + " " + (c[0] - (e[0] - b[0]) / 6) + " " + (c[1] - (e[1] - b[1]) / 6)
               + " " + c[0] + " " + c[1];
        }
        return d;
    }

    Timer {
        interval: 20000
        running: root.visible && (["analog", "digital", "month"].indexOf(root.kind) >= 0
                                  || (root.kind === "panel" && root.spec.content === "status"))
        repeat: true
        onTriggered: root.now = new Date()
    }

    Loader {
        anchors.centerIn: parent
        sourceComponent: {
            switch (root.kind) {
            case "analog":
                return analog;
            case "digital":
                return digital;
            case "month":
                return month;
            case "chart":
                return chart;
            case "cores":
                return cores;
            case "donut":
                return donut;
            case "sensor":
                return sensor;
            case "folder":
                return folder;
            case "rows":
                return rows;
            case "player":
                return player;
            case "sliders":
                return sliders;
            case "battery":
                return battery;
            case "screens":
                return screens;
            case "buttons":
                return buttons;
            case "search":
                return search;
            case "layout":
                return layout;
            case "panel":
                return panel;
            default:
                return glyph;
            }
        }
    }

    component Bar: Rectangle {
        height: 6
        radius: 3
        color: M3.withAlpha(M3.surfaceContent, 0.22)
    }

    component Dot: Rectangle {
        width: 20
        height: 20
        radius: 10
        color: root.dim
    }

    component Arc: ShapePath {
        id: arc
        property real sweep: 360
        property real start: -90
        strokeWidth: 12
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc {
            centerX: 48
            centerY: 48
            radiusX: 42
            radiusY: 42
            startAngle: arc.start
            sweepAngle: arc.sweep
        }
    }

    Component {
        id: analog

        MaterialShape {
            width: 104
            height: 104
            shape: "cookie12"
            color: M3.primaryContainer

            Item {
                anchors.fill: parent
                rotation: (root.now.getHours() % 12 + root.now.getMinutes() / 60) * 30

                Rectangle {
                    x: parent.width / 2 - 4
                    y: parent.height / 2 - 26
                    width: 8
                    height: 30
                    radius: 4
                    color: M3.primary
                }
            }
            Item {
                anchors.fill: parent
                rotation: root.now.getMinutes() * 6

                Rectangle {
                    x: parent.width / 2 - 3
                    y: parent.height / 2 - 38
                    width: 6
                    height: 41
                    radius: 3
                    color: M3.tertiary
                }
            }
            Rectangle {
                anchors.centerIn: parent
                width: 10
                height: 10
                radius: 5
                color: M3.primaryContainerContent
            }
        }
    }

    Component {
        id: digital

        Column {
            spacing: 2

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.time()
                color: M3.primary
                font.family: M3.typeface
                font.pixelSize: 42
                font.weight: Font.Medium
                font.letterSpacing: -1
                font.features: { "tnum": 1 }
            }
            MText {
                anchors.horizontalCenter: parent.horizontalCenter
                role: "bodyMedium"
                color: M3.surfaceVariantContent
                text: {
                    const date = Qt.locale().toString(root.now, "ddd, d MMM");
                    return date.charAt(0).toUpperCase() + date.slice(1);
                }
            }
        }
    }

    Component {
        id: month

        Column {
            spacing: 4

            MText {
                role: "labelMedium"
                text: {
                    const name = Qt.locale().standaloneMonthName(root.now.getMonth());
                    return name.charAt(0).toUpperCase() + name.slice(1);
                }
            }
            Grid {
                columns: 7
                rowSpacing: 1
                columnSpacing: 2

                Repeater {
                    model: 35

                    delegate: Rectangle {
                        id: day

                        required property int index
                        readonly property date date: {
                            const first = new Date(root.now.getFullYear(), root.now.getMonth(), 1);
                            const offset = (first.getDay() - Qt.locale().firstDayOfWeek + 7) % 7;
                            return new Date(root.now.getFullYear(), root.now.getMonth(), 1 - offset + index);
                        }
                        readonly property bool today: date.getDate() === root.now.getDate() && date.getMonth() === root.now.getMonth()

                        width: 16
                        height: 16
                        radius: 8
                        color: today ? M3.primary : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: day.date.getDate()
                            color: day.today ? M3.primaryContent
                                 : day.date.getMonth() === root.now.getMonth() ? M3.surfaceContent : M3.withAlpha(M3.surfaceContent, 0.38)
                            font.family: M3.typeface
                            font.pixelSize: 9
                            font.features: { "tnum": 1 }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: chart

        Item {
            width: 152
            height: 104

            Row {
                spacing: 6

                MIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 18
                    source: root.spec.badge
                    color: M3.primary
                }
                MText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "titleSmall"
                    text: root.spec.value || ""
                }
            }
            Item {
                y: 34
                width: parent.width
                height: 64

                Repeater {
                    model: root.spec.lines

                    delegate: Shape {
                        id: line

                        required property var modelData
                        required property int index
                        readonly property color ink: index === 0 ? M3.primary : M3.tertiary
                        readonly property string outline: root.curve(modelData, width, height)

                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            strokeWidth: -1
                            strokeColor: "transparent"
                            fillColor: root.spec.lines.length === 1 ? M3.withAlpha(M3.primary, 0.18) : "transparent"
                            PathSvg {
                                path: line.outline + " L " + line.width + " " + line.height + " L 0 " + line.height + " Z"
                            }
                        }
                        ShapePath {
                            strokeWidth: 3
                            strokeColor: line.ink
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            joinStyle: ShapePath.RoundJoin
                            PathSvg {
                                path: line.outline
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: cores

        Row {
            spacing: 7

            Repeater {
                model: [0.8, 0.35, 0.6, 0.25, 0.9, 0.45, 0.3, 0.65]

                delegate: Rectangle {
                    required property real modelData
                    required property int index
                    width: 12
                    height: 92
                    radius: 6
                    color: M3.surfaceContainerHighest

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: Math.max(width, parent.height * parent.modelData)
                        radius: 6
                        color: parent.index % 2 ? M3.tertiary : M3.primary
                    }
                }
            }
        }
    }

    Component {
        id: donut

        Item {
            width: 96
            height: 96

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                Arc {
                    strokeColor: M3.surfaceContainerHighest
                }
                Arc {
                    strokeColor: M3.primary
                    sweep: 360 * root.spec.fraction
                }
            }
            MText {
                anchors.centerIn: parent
                role: "titleMedium"
                text: Math.round(root.spec.fraction * 100) + "%"
            }
        }
    }

    Component {
        id: sensor

        Item {
            width: 96
            height: 96

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                Arc {
                    strokeColor: M3.surfaceContainerHighest
                    start: 135
                    sweep: 270
                }
                Arc {
                    strokeColor: M3.tertiary
                    start: 135
                    sweep: 270 * 0.42
                }
            }
            MText {
                anchors.centerIn: parent
                role: "titleLarge"
                text: "42%"
            }
            MIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                size: 18
                source: "ksysguardd"
                color: M3.surfaceVariantContent
            }
        }
    }

    Component {
        id: folder

        Grid {
            columns: 3
            columnSpacing: 16
            rowSpacing: 10

            Repeater {
                model: ["folder", "folder", "image-x-generic", "text-x-generic", "audio-x-generic", "application-x-archive"]

                delegate: Column {
                    required property string modelData
                    required property int index
                    spacing: 5

                    MIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        size: 30
                        source: parent.modelData
                        color: parent.index < 2 ? M3.primary : M3.surfaceVariantContent
                    }
                    Bar {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 28
                        height: 4
                        radius: 2
                    }
                }
            }
        }
    }

    Component {
        id: rows

        Column {
            spacing: 6

            Repeater {
                model: root.spec.rows

                delegate: Rectangle {
                    id: row

                    required property var modelData
                    required property int index
                    readonly property color ink: modelData.active ? M3.primaryContainerContent : M3.surfaceVariantContent

                    width: 152
                    height: root.spec.tall ? 44 : 30
                    radius: root.spec.tall ? 14 : 15
                    color: modelData.active ? M3.primaryContainer : M3.surfaceContainerHighest

                    Row {
                        x: 9
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 9

                        MIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            size: 18
                            source: row.modelData.icon
                            color: row.ink
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Bar {
                                width: [72, 54, 64][row.index % 3]
                                color: M3.withAlpha(row.ink, 0.45)
                            }
                            Bar {
                                visible: !!root.spec.tall
                                width: 92
                                color: M3.withAlpha(row.ink, 0.25)
                            }
                        }
                    }
                    MIcon {
                        visible: !!row.modelData.trailing
                        anchors.right: parent.right
                        anchors.rightMargin: 9
                        anchors.verticalCenter: parent.verticalCenter
                        size: 18
                        source: row.modelData.trailing || ""
                        color: row.ink
                    }
                }
            }
        }
    }

    Component {
        id: player

        Rectangle {
            width: 152
            height: 108
            radius: 20
            color: M3.secondaryContainer

            Rectangle {
                id: cover
                x: 10
                y: 10
                width: 50
                height: 50
                radius: 12
                color: M3.tertiaryContainer

                MIcon {
                    anchors.centerIn: parent
                    size: 24
                    source: "audio-x-generic"
                    color: M3.tertiaryContainerContent
                }
            }
            Column {
                x: cover.x + cover.width + 10
                y: 18
                spacing: 7

                Bar {
                    width: 62
                    color: M3.withAlpha(M3.secondaryContainerContent, 0.5)
                }
                Bar {
                    width: 42
                    color: M3.withAlpha(M3.secondaryContainerContent, 0.3)
                }
            }
            Rectangle {
                x: cover.x + cover.width + 10
                y: 48
                width: 72
                height: 4
                radius: 2
                color: M3.withAlpha(M3.secondaryContainerContent, 0.25)

                Rectangle {
                    width: parent.width * 0.4
                    height: parent.height
                    radius: 2
                    color: M3.primary
                }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                spacing: 14

                MIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 20
                    source: "media-skip-backward"
                    color: M3.secondaryContainerContent
                }
                Rectangle {
                    width: 40
                    height: 32
                    radius: 12
                    color: M3.primary

                    MIcon {
                        anchors.centerIn: parent
                        size: 20
                        source: "media-playback-start"
                        color: M3.primaryContent
                    }
                }
                MIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 20
                    source: "media-skip-forward"
                    color: M3.secondaryContainerContent
                }
            }
        }
    }

    Component {
        id: sliders

        Column {
            spacing: 14

            Repeater {
                model: root.spec.sliders

                delegate: Row {
                    id: slider

                    required property var modelData
                    spacing: 10

                    MIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        size: 22
                        source: slider.modelData.icon
                        color: M3.surfaceVariantContent
                    }
                    Item {
                        id: track
                        readonly property real split: width * slider.modelData.value
                        anchors.verticalCenter: parent.verticalCenter
                        width: 112
                        height: 30

                        Rectangle {
                            y: 7
                            width: track.split - 5
                            height: 16
                            radius: 8
                            color: M3.primary
                        }
                        Rectangle {
                            x: track.split - 2
                            width: 4
                            height: track.height
                            radius: 2
                            color: M3.primary
                        }
                        Rectangle {
                            x: track.split + 5
                            y: 7
                            width: track.width - track.split - 5
                            height: 16
                            radius: 8
                            color: M3.secondaryContainer
                        }
                    }
                }
            }
        }
    }

    Component {
        id: battery

        Column {
            spacing: 10

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 3

                Rectangle {
                    id: cell
                    width: 96
                    height: 46
                    radius: 14
                    color: M3.surfaceContainerHighest

                    Rectangle {
                        x: 5
                        y: 5
                        width: (cell.width - 10) * root.spec.fraction
                        height: cell.height - 10
                        radius: 9
                        color: M3.primary

                        MIcon {
                            anchors.centerIn: parent
                            size: 22
                            source: "power-profile-performance"
                            color: M3.primaryContent
                        }
                    }
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 5
                    height: 16
                    radius: 2.5
                    color: M3.surfaceContainerHighest
                }
            }
            MText {
                anchors.horizontalCenter: parent.horizontalCenter
                role: "titleMedium"
                text: Math.round(root.spec.fraction * 100) + "%"
            }
        }
    }

    Component {
        id: screens

        Row {
            spacing: 10

            Repeater {
                model: [{ width: 78, height: 50, tone: "primary" }, { width: 52, height: 38, tone: "secondary" }]

                delegate: Column {
                    id: screen

                    required property var modelData
                    required property int index
                    anchors.bottom: parent.bottom
                    spacing: 3

                    Rectangle {
                        width: screen.modelData.width
                        height: screen.modelData.height
                        radius: 10
                        color: root.container(screen.modelData.tone)

                        MText {
                            anchors.centerIn: parent
                            role: "titleMedium"
                            text: screen.index + 1
                            color: root.onContainer(screen.modelData.tone)
                        }
                    }
                    Bar {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 18
                        height: 4
                        radius: 2
                    }
                }
            }
        }
    }

    Component {
        id: buttons

        Row {
            spacing: 16

            Repeater {
                model: root.spec.buttons

                delegate: Rectangle {
                    id: button

                    required property string modelData
                    required property int index
                    readonly property bool last: index === root.spec.buttons.length - 1

                    width: 58
                    height: 58
                    radius: last ? 20 : 29
                    color: last ? M3.primary : M3.secondaryContainer

                    MIcon {
                        anchors.centerIn: parent
                        size: 26
                        source: button.modelData
                        color: button.last ? M3.primaryContent : M3.secondaryContainerContent
                    }
                }
            }
        }
    }

    Component {
        id: search

        Column {
            spacing: 10

            Rectangle {
                width: 152
                height: 40
                radius: 20
                color: M3.surfaceContainerHighest

                MIcon {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    size: 20
                    source: "system-search"
                    color: M3.surfaceVariantContent
                }
                Bar {
                    x: 42
                    anchors.verticalCenter: parent.verticalCenter
                    width: 64
                }
            }
            Repeater {
                model: ["folder", "text-x-generic"]

                delegate: Row {
                    required property string modelData
                    required property int index
                    x: 12
                    spacing: 10

                    MIcon {
                        size: 18
                        source: parent.modelData
                        color: parent.index === 0 ? M3.primary : M3.surfaceVariantContent
                    }
                    Bar {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.index === 0 ? 76 : 58
                    }
                }
            }
        }
    }

    Component {
        id: layout

        Column {
            spacing: 8

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 84
                height: 56
                radius: 18
                color: M3.primaryContainer

                MText {
                    anchors.centerIn: parent
                    role: "headlineSmall"
                    text: Qt.locale().name.split("_")[0].toUpperCase()
                    color: M3.primaryContainerContent
                }
            }
            MIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                size: 22
                source: "input-keyboard"
                color: M3.surfaceVariantContent
            }
        }
    }

    Component {
        id: glyph

        MaterialShape {
            readonly property string tone: root.spec && root.spec.tone ? root.spec.tone : "primary"
            width: 88
            height: 88
            shape: root.spec && root.spec.shape ? root.spec.shape : "cookie9"
            color: root.container(tone)

            MIcon {
                anchors.centerIn: parent
                visible: !!root.spec
                size: 36
                source: root.spec ? root.spec.icon : ""
                color: root.onContainer(parent.tone)
            }
            Kirigami.Icon {
                anchors.centerIn: parent
                visible: !root.spec
                implicitWidth: 36
                implicitHeight: 36
                source: root.icon
                animated: false
            }
        }
    }

    Component {
        id: panel

        Item {
            width: 156
            height: root.spec.content === "launcher" ? 112 : 42

            Rectangle {
                visible: root.spec.content === "launcher"
                anchors.horizontalCenter: parent.horizontalCenter
                width: 108
                height: 58
                radius: 16
                color: M3.surfaceContainerHighest

                Grid {
                    anchors.centerIn: parent
                    columns: 4
                    spacing: 8

                    Repeater {
                        model: 8

                        delegate: Rectangle {
                            required property int index
                            width: 16
                            height: 16
                            radius: 8
                            color: root.container(["primary", "secondary", "tertiary"][index % 3])
                        }
                    }
                }
            }
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 42
                radius: 21
                color: M3.surfaceContainerHighest

                Loader {
                    anchors.centerIn: parent
                    sourceComponent: {
                        switch (root.spec.content) {
                        case "launcher":
                            return panelLauncher;
                        case "status":
                            return panelStatus;
                        case "dock":
                            return panelDock;
                        case "chips":
                            return panelChips;
                        case "tray":
                            return panelTray;
                        case "pager":
                            return panelPager;
                        case "tabs":
                            return panelTabs;
                        case "menu":
                            return panelMenu;
                        case "spacer":
                            return panelSpacer;
                        case "separator":
                            return panelSeparator;
                        default:
                            return panelButton;
                        }
                    }
                }
            }
        }
    }

    Component {
        id: panelLauncher

        Row {
            spacing: 8

            Rectangle {
                width: 30
                height: 30
                radius: 15
                color: M3.primary

                MIcon {
                    anchors.centerIn: parent
                    size: 18
                    source: root.spec.icon
                    color: M3.primaryContent
                }
            }
            Repeater {
                model: 4

                delegate: Dot {
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    Component {
        id: panelStatus

        Rectangle {
            width: statusRow.implicitWidth + 20
            height: 30
            radius: 15
            color: M3.secondaryContainer

            Row {
                id: statusRow
                anchors.centerIn: parent
                spacing: 6

                Repeater {
                    model: ["network-wireless", "audio-volume-high", "battery-full"]

                    delegate: MIcon {
                        required property string modelData
                        anchors.verticalCenter: parent.verticalCenter
                        size: 16
                        source: modelData
                        color: M3.secondaryContainerContent
                    }
                }
                MText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "labelLarge"
                    text: root.time()
                    color: M3.secondaryContainerContent
                }
            }
        }
    }

    Component {
        id: panelDock

        Row {
            spacing: 5

            Repeater {
                model: [{ icon: "folder", tone: "primary" }, { icon: "applications-internet", tone: "secondary" },
                        { icon: "audio-x-generic", tone: "tertiary" }, { icon: "image-x-generic", tone: "primary" },
                        { icon: "utilities-terminal", tone: "secondary" }]

                delegate: Rectangle {
                    required property var modelData
                    width: 26
                    height: 26
                    radius: 13
                    color: root.container(modelData.tone)

                    MIcon {
                        anchors.centerIn: parent
                        size: 15
                        source: parent.modelData.icon
                        color: root.onContainer(parent.modelData.tone)
                    }
                }
            }
        }
    }

    Component {
        id: panelChips

        Row {
            spacing: 6

            Repeater {
                model: ["folder", "applications-internet"]

                delegate: Rectangle {
                    id: chip

                    required property string modelData
                    required property int index
                    width: 70
                    height: 30
                    radius: 15
                    color: index === 0 ? M3.secondaryContainer : "transparent"

                    Row {
                        x: 7
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        MIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            size: 16
                            source: chip.modelData
                            color: chip.index === 0 ? M3.secondaryContainerContent : M3.surfaceVariantContent
                        }
                        Bar {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 32
                        }
                    }
                }
            }
        }
    }

    Component {
        id: panelTray

        Row {
            spacing: 10

            Repeater {
                model: ["arrow-up", "bluetooth", "network-wireless", "audio-volume-high", "battery-full"]

                delegate: MIcon {
                    required property string modelData
                    required property int index
                    size: 18
                    source: modelData
                    color: index === 0 ? M3.surfaceVariantContent : M3.surfaceContent
                }
            }
        }
    }

    Component {
        id: panelPager

        Row {
            spacing: 5

            Repeater {
                model: 4

                delegate: Rectangle {
                    required property int index
                    width: 30
                    height: 24
                    radius: 7
                    color: index === 0 ? M3.primaryContainer : root.dim

                    Rectangle {
                        visible: parent.index === 0
                        x: 5
                        y: 5
                        width: 13
                        height: 9
                        radius: 3
                        color: M3.primary
                    }
                    Rectangle {
                        visible: parent.index === 0 || parent.index === 2
                        x: parent.index === 0 ? 12 : 8
                        y: parent.index === 0 ? 11 : 7
                        width: 12
                        height: 8
                        radius: 3
                        color: parent.index === 0 ? M3.tertiary : M3.withAlpha(M3.surfaceContent, 0.3)
                    }
                }
            }
        }
    }

    Component {
        id: panelTabs

        Row {
            spacing: 4

            Repeater {
                model: 3

                delegate: Rectangle {
                    required property int index
                    width: 44
                    height: 28
                    radius: 14
                    color: index === 0 ? M3.secondaryContainer : "transparent"

                    Bar {
                        anchors.centerIn: parent
                        width: 24
                        color: parent.index === 0 ? M3.withAlpha(M3.secondaryContainerContent, 0.6) : M3.withAlpha(M3.surfaceContent, 0.22)
                    }
                }
            }
        }
    }

    Component {
        id: panelMenu

        Row {
            spacing: 12

            MIcon {
                anchors.verticalCenter: parent.verticalCenter
                size: 18
                source: "kernora-menu"
                color: M3.surfaceContent
            }
            Repeater {
                model: [26, 22, 30]

                delegate: Bar {
                    required property real modelData
                    anchors.verticalCenter: parent.verticalCenter
                    width: modelData
                }
            }
        }
    }

    Component {
        id: panelSpacer

        Row {
            spacing: 8

            Dot {
                anchors.verticalCenter: parent.verticalCenter
            }
            Rectangle {
                width: 72
                height: 26
                radius: 13
                color: M3.primaryContainer

                MIcon {
                    anchors.centerIn: parent
                    size: 18
                    source: "distribute-horizontal-x"
                    color: M3.primaryContainerContent
                }
            }
            Dot {
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    Component {
        id: panelSeparator

        Row {
            spacing: 10

            Dot {
                anchors.verticalCenter: parent.verticalCenter
            }
            Dot {
                anchors.verticalCenter: parent.verticalCenter
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: 26
                radius: 1.5
                color: M3.primary
            }
            Dot {
                anchors.verticalCenter: parent.verticalCenter
            }
            Dot {
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    Component {
        id: panelButton

        Row {
            spacing: 10

            Dot {
                anchors.verticalCenter: parent.verticalCenter
            }
            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: M3.primaryContainer

                MIcon {
                    anchors.centerIn: parent
                    size: 18
                    source: root.spec.glyph || root.spec.icon
                    color: M3.primaryContainerContent
                }
            }
            Dot {
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
