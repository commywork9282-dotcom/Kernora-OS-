/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import "m3"

Item {
    id: root

    required property date now
    required property int monthOffset

    signal shift(int delta)
    signal backToToday()

    readonly property date shown: new Date(now.getFullYear(), now.getMonth() + monthOffset, 1)
    readonly property int firstDay: Qt.locale().firstDayOfWeek % 7
    readonly property int lead: (shown.getDay() - firstDay + 7) % 7
    readonly property int rows: Math.ceil((lead + new Date(shown.getFullYear(), shown.getMonth() + 1, 0).getDate()) / 7)
    readonly property real cell: 44
    readonly property bool dayFirst: {
        const pattern = Qt.locale().dateFormat(Locale.ShortFormat);
        return pattern.indexOf("d") >= 0 && pattern.indexOf("d") < pattern.indexOf("M");
    }

    function cellDate(index: int): date {
        return new Date(shown.getFullYear(), shown.getMonth(), 1 - lead + index);
    }

    function capitalised(text: string): string {
        return text.charAt(0).toUpperCase() + text.slice(1);
    }

    Layout.preferredWidth: column.implicitWidth + 32
    Layout.preferredHeight: column.implicitHeight + 32
    Layout.minimumWidth: Layout.preferredWidth
    Layout.minimumHeight: Layout.preferredHeight
    Layout.maximumWidth: Layout.preferredWidth
    Layout.maximumHeight: Layout.preferredHeight

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.pixelDelta.y;
            if (Math.abs(delta) >= 60) {
                root.shift(delta > 0 ? -1 : 1);
            }
        }
    }

    ColumnLayout {
        id: column
        anchors.centerIn: parent
        spacing: 0

        MText {
            Layout.leftMargin: 12
            role: "labelLarge"
            color: M3.primary
            text: root.capitalised(root.now.toLocaleDateString(Qt.locale(), "dddd"))
        }
        MText {
            Layout.leftMargin: 12
            Layout.bottomMargin: 12
            role: "headlineSmall"
            color: M3.surfaceContent
            text: root.now.toLocaleDateString(Qt.locale(), root.dayFirst ? "d MMMM yyyy" : "MMMM d, yyyy")
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 12
            spacing: 0

            MText {
                Layout.fillWidth: true
                role: "titleSmall"
                color: M3.surfaceVariantContent
                elide: Text.ElideRight
                text: root.capitalised(Qt.locale().standaloneMonthName(root.shown.getMonth(), Locale.LongFormat)) + " " + root.shown.getFullYear()

                MouseArea {
                    anchors.fill: parent
                    enabled: root.monthOffset !== 0
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.backToToday()
                }
            }
            MIconButton {
                icon: "go-previous"
                size: 40
                iconSize: 20
                onClicked: root.shift(-1)
            }
            MIconButton {
                icon: "go-next"
                size: 40
                iconSize: 20
                onClicked: root.shift(1)
            }
        }

        Grid {
            Layout.topMargin: 4
            columns: 7

            Repeater {
                model: 7
                delegate: Item {
                    required property int index
                    width: root.cell
                    height: 32
                    MText {
                        anchors.centerIn: parent
                        role: "labelMedium"
                        color: M3.surfaceVariantContent
                        text: Qt.locale().dayName((root.firstDay + index) % 7, Locale.NarrowFormat).toUpperCase()
                    }
                }
            }
            Repeater {
                model: root.rows * 7
                delegate: Item {
                    id: day
                    required property int index
                    readonly property date when: root.cellDate(index)
                    readonly property bool inMonth: when.getMonth() === root.shown.getMonth()
                    readonly property bool today: when.toDateString() === root.now.toDateString()
                    width: root.cell
                    height: root.cell - 4

                    Rectangle {
                        anchors.centerIn: parent
                        width: 36
                        height: 36
                        radius: 18
                        visible: day.today
                        color: M3.primary
                    }
                    MText {
                        anchors.centerIn: parent
                        role: "bodyMedium"
                        text: day.when.getDate()
                        color: day.today ? M3.primaryContent : M3.surfaceContent
                        opacity: day.inMonth ? 1 : 0.38
                        font.weight: day.today ? Font.DemiBold : Font.Normal
                    }
                }
            }
        }
    }
}
