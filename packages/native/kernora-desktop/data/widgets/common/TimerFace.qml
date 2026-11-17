/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kernora.m3

Item {
    id: face

    property var items: []
    property string title: "Timers"
    property bool interactive: true

    signal activated(int index)
    signal cancelled(int index)
    signal added()

    readonly property bool dark: M3.dark
    readonly property color surface: dark ? M3.accent1_800 : M3.accent1_50
    readonly property color panel: dark ? Qt.tint(surface, "#1affffff") : M3.accent1_100
    readonly property color ink: dark ? M3.neutral2_100 : M3.neutral1_900
    readonly property color primary: dark ? M3.accent1_200 : M3.accent1_600
    readonly property color onPrimary: dark ? M3.accent1_800 : M3.accent1_10
    readonly property color runFill: dark ? M3.accent1_600 : M3.accent1_300
    readonly property color runInk: dark ? M3.accent1_50 : M3.accent1_900
    readonly property color pauseFill: dark ? M3.accent2_700 : M3.accent2_200
    readonly property color doneFill: dark ? M3.accent3_600 : M3.accent3_200

    readonly property string timerPath: "M360-840v-80h240v80H360Zm80 440h80v-240h-80v240Zm40 320q-74 0-139.5-28.5T226-186q-49-49-77.5-114.5T120-440q0-74 28.5-139.5T226-694q49-49 114.5-77.5T480-800q62 0 119 20t107 58l56-56 56 56-56 56q38 50 58 107t20 119q0 74-28.5 139.5T734-186q-49 49-114.5 77.5T480-80Zm0-80q116 0 198-82t82-198q0-116-82-198t-198-82q-116 0-198 82t-82 198q0 116 82 198t198 82Zm0-280Z"
    readonly property string addPath: "M440-440H200v-80h240v-240h80v240h240v80H520v240h-80v-240Z"
    readonly property string closePath: "m256-200-56-56 224-224-224-224 56-56 224 224 224-224 56 56-224 224 224 224-56 56-224-224-224 224Z"

    readonly property real pad: 16
    readonly property real headerHeight: 52
    readonly property real gap: 12
    readonly property real bodyHeight: height - headerHeight - pad
    readonly property real bodyWidth: width - 2 * pad
    readonly property string mode: width < 170 || height < 150 ? "single"
        : width >= height * 1.35 && width >= 320 ? "columns" : "rows"
    readonly property int shown: Math.min((items || []).length, 3)
    readonly property int roomRows: Math.max(1, Math.floor((bodyHeight + gap) / (44 + gap)))
    readonly property bool plusInBody: mode === "rows"
        ? (bodyHeight - 3 * gap) / (shown + 1) >= 52 && roomRows > shown
        : mode === "columns" && bodyHeight >= 2 * 52 + gap
    readonly property int rows: mode === "rows" ? Math.max(1, Math.min(shown, roomRows - (plusInBody ? 1 : 0))) : shown
    readonly property real rowHeight: rows > 0 ? (bodyHeight - (rows + (plusInBody ? 1 : 0) - 1) * gap) / (rows + (plusInBody ? 1 : 0)) : 0

    function remainingText(ms: real): string {
        const total = Math.max(0, Math.ceil(ms / 1000));
        const hours = Math.floor(total / 3600);
        const minutes = Math.floor(total % 3600 / 60);
        const seconds = String(total % 60).padStart(2, "0");
        return hours > 0 ? hours + ":" + String(minutes).padStart(2, "0") + ":" + seconds : minutes + ":" + seconds;
    }

    function cell(index: int): var {
        if (mode === "single") {
            return { x: 0, y: 0, w: width, h: height, r: 28 };
        }
        const top = headerHeight;
        if (mode === "rows") {
            return { x: pad, y: top + index * (rowHeight + gap), w: bodyWidth, h: rowHeight, r: rowHeight / 2 };
        }
        const column = (bodyWidth - 2 * gap) / 3;
        const plusHeight = Math.min(64, (bodyHeight - gap) / 2);
        const x = pad + index * (column + gap);
        if (index === 2) {
            const h = plusInBody ? bodyHeight - plusHeight - gap : bodyHeight;
            return { x: x, y: top, w: column, h: h, r: Math.min(column, h) / 2 };
        }
        return { x: x, y: top, w: column, h: bodyHeight, r: index === 0 ? Math.min(column, bodyHeight) / 2 : column * 0.26 };
    }

    function plusCell(): var {
        if (mode === "rows") {
            return { x: pad, y: headerHeight + rows * (rowHeight + gap), w: bodyWidth, h: rowHeight };
        }
        const column = (bodyWidth - 2 * gap) / 3;
        const plusHeight = Math.min(64, (bodyHeight - gap) / 2);
        return { x: pad + 2 * (column + gap), y: headerHeight + bodyHeight - plusHeight, w: column, h: plusHeight };
    }

    FontMetrics {
        id: metrics
        font.family: M3.typeface
        font.pixelSize: 200
    }

    readonly property real digitRatio: Math.max(0.5, metrics.tightBoundingRect("0").height / 200)

    Rectangle {
        anchors.fill: parent
        radius: 28
        color: face.mode === "single" && face.items.length > 0 && face.items[0].state === "done" ? face.doneFill : face.surface
    }

    SymbolIcon {
        x: face.pad + 2
        y: face.mode === "single" ? face.pad : (face.headerHeight - size) / 2 + 2
        size: 22
        color: face.primary
        path: face.timerPath
    }

    Text {
        visible: face.mode !== "single"
        x: face.pad + 34
        width: face.width - x - face.pad - 40
        height: face.headerHeight + 4
        verticalAlignment: Text.AlignVCenter
        text: face.title
        color: face.ink
        font.family: M3.typeface
        font.pixelSize: 16
        font.weight: Font.Medium
        elide: Text.ElideRight
        textFormat: Text.PlainText
    }

    Item {
        visible: face.mode !== "single" && !face.plusInBody
        x: face.width - face.pad - width + 6
        y: (face.headerHeight - height) / 2 + 2
        width: 40
        height: 40

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: face.ink
            opacity: headerPlus.pressed ? 0.12 : headerPlus.containsMouse ? 0.08 : 0
        }

        SymbolIcon {
            anchors.centerIn: parent
            size: 24
            color: face.ink
            path: face.addPath
        }

        MouseArea {
            id: headerPlus
            anchors.fill: parent
            enabled: face.interactive
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: face.added()
        }
    }

    Repeater {
        model: face.mode === "single" ? Math.min(1, face.items.length) : face.mode === "rows" ? face.rows : face.shown

        Item {
            id: preset

            required property int index
            readonly property var item: face.items[index] || ({})
            readonly property var box: face.cell(index)
            readonly property string state: item.state || "idle"
            readonly property bool single: face.mode === "single"
            readonly property bool tall: !single && height > width * 1.2
            readonly property real fraction: item.total > 0 ? Math.max(0, Math.min(1, item.remaining / item.total)) : 0
            readonly property real capHeight: single ? Math.min(face.height * 0.3, face.width * 0.17, 30)
                : face.mode === "rows" ? Math.min(height * 0.34, 26) : Math.min(width * 0.2, 22)

            x: box.x
            y: box.y
            width: box.w
            height: box.h

            Rectangle {
                id: shape
                anchors.fill: parent
                visible: !preset.single
                radius: preset.box.r
                color: preset.state === "done" ? face.doneFill : face.panel

                SequentialAnimation on opacity {
                    running: preset.state === "done" && preset.visible
                    loops: Animation.Infinite
                    alwaysRunToEnd: true
                    NumberAnimation { to: 0.55; duration: 500; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 500; easing.type: Easing.InOutSine }
                }
            }

            Rectangle {
                visible: !preset.single && (preset.state === "running" || preset.state === "paused")
                y: preset.tall ? parent.height - height : 0
                width: preset.tall ? parent.width : parent.width * preset.fraction
                height: preset.tall ? parent.height * preset.fraction : parent.height
                radius: Math.min(preset.box.r, width / 2, height / 2)
                color: preset.state === "paused" ? face.pauseFill : face.runFill

                Behavior on width {
                    NumberAnimation {
                        duration: 900
                        easing.type: Easing.Linear
                    }
                }

                Behavior on height {
                    NumberAnimation {
                        duration: 900
                        easing.type: Easing.Linear
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                visible: !preset.single
                radius: preset.box.r
                color: face.ink
                opacity: presetMouse.pressed ? 0.12 : presetMouse.containsMouse ? 0.06 : 0
            }

            Text {
                anchors.fill: parent
                anchors.leftMargin: preset.single && face.width >= face.height * 1.6 ? 40 : 8
                anchors.rightMargin: preset.state === "paused" && !preset.single && !preset.tall ? Math.min(48, parent.width * 0.3) : 8
                anchors.topMargin: preset.single && face.width < face.height * 1.6 ? 30 : 0
                anchors.bottomMargin: preset.state === "paused" && preset.tall ? 44 : 0
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: preset.state === "idle" ? (preset.item.label || "") : face.remainingText(preset.item.remaining || 0)
                color: preset.state === "running" ? face.runInk : face.ink
                font.family: M3.typeface
                font.pixelSize: Math.max(8, Math.round(preset.capHeight / face.digitRatio))
                font.features: { "tnum": 1 }
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 8
                textFormat: Text.PlainText
            }

            MouseArea {
                id: presetMouse
                anchors.fill: parent
                enabled: face.interactive
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: face.activated(preset.index)
            }

            Item {
                visible: preset.state === "paused" && !preset.single
                x: preset.tall ? (parent.width - width) / 2 : parent.width - width - Math.max(4, Math.min(12, parent.height / 2 - 20))
                y: preset.tall ? parent.height - height - 8 : (parent.height - height) / 2
                width: 40
                height: 40

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: face.ink
                    opacity: cancelMouse.pressed ? 0.14 : cancelMouse.containsMouse ? 0.08 : 0
                }

                SymbolIcon {
                    anchors.centerIn: parent
                    size: 20
                    color: face.ink
                    path: face.closePath
                }

                MouseArea {
                    id: cancelMouse
                    anchors.fill: parent
                    enabled: face.interactive
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: face.cancelled(preset.index)
                }
            }
        }
    }

    Item {
        readonly property var box: face.plusInBody && face.mode !== "single" ? face.plusCell() : ({ x: 0, y: 0, w: 0, h: 0 })

        visible: face.plusInBody && face.mode !== "single"
        x: box.x
        y: box.y
        width: box.w
        height: box.h

        Rectangle {
            anchors.fill: parent
            radius: Math.min(width, height) / 2
            color: face.primary
        }

        Rectangle {
            anchors.fill: parent
            radius: Math.min(width, height) / 2
            color: face.onPrimary
            opacity: bodyPlus.pressed ? 0.12 : bodyPlus.containsMouse ? 0.08 : 0
        }

        SymbolIcon {
            anchors.centerIn: parent
            size: 28
            color: face.onPrimary
            path: face.addPath
        }

        MouseArea {
            id: bodyPlus
            anchors.fill: parent
            enabled: face.interactive
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: face.added()
        }
    }
}
