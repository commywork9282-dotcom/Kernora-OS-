/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import "m3"

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    switchWidth: Plasmoid.configuration.placed ? 0 : 299
    switchHeight: Plasmoid.configuration.placed ? 0 : 309

    Timer {
        running: !Plasmoid.configuration.placed
        interval: 2000
        onTriggered: Plasmoid.configuration.placed = true
    }

    property date now: new Date()
    property int monthOffset: 0
    readonly property date shown: new Date(now.getFullYear(), now.getMonth() + monthOffset, 1)
    readonly property int firstDay: Qt.locale().firstDayOfWeek % 7
    readonly property int lead: (shown.getDay() - firstDay + 7) % 7

    toolTipMainText: Qt.locale().toString(now, Locale.LongFormat)
    toolTipSubText: ""

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    function cellDate(index: int): date {
        return new Date(shown.getFullYear(), shown.getMonth(), 1 - lead + index);
    }

    fullRepresentation: WidgetSurface {
        id: card
        Layout.preferredWidth: 300
        Layout.preferredHeight: 310
        Layout.minimumWidth: 220
        Layout.minimumHeight: 230

        readonly property real cell: Math.min((width - 24) / 7, (height - 84) / 7)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                spacing: 0

                MText {
                    Layout.fillWidth: true
                    role: "titleMedium"
                    color: M3.surfaceContent
                    elide: Text.ElideRight
                    text: {
                        const month = Qt.locale().standaloneMonthName(root.shown.getMonth(), Locale.LongFormat);
                        return month.charAt(0).toUpperCase() + month.slice(1) + " " + root.shown.getFullYear();
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: root.monthOffset !== 0
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.monthOffset = 0
                    }
                }
                MIconButton {
                    icon: "go-previous"
                    size: 36
                    iconSize: 20
                    onClicked: root.monthOffset -= 1
                }
                MIconButton {
                    icon: "go-next"
                    size: 36
                    iconSize: 20
                    onClicked: root.monthOffset += 1
                }
            }

            Grid {
                Layout.alignment: Qt.AlignHCenter
                columns: 7

                Repeater {
                    model: 7
                    delegate: Item {
                        required property int index
                        width: card.cell
                        height: card.cell * 0.8
                        MText {
                            anchors.centerIn: parent
                            role: "labelMedium"
                            color: M3.surfaceVariantContent
                            text: Qt.locale().dayName((root.firstDay + index) % 7, Locale.NarrowFormat).toUpperCase()
                        }
                    }
                }
                Repeater {
                    model: 42
                    delegate: Item {
                        id: day
                        required property int index
                        readonly property date when: root.cellDate(index)
                        readonly property bool inMonth: when.getMonth() === root.shown.getMonth()
                        readonly property bool today: when.toDateString() === root.now.toDateString()
                        width: card.cell
                        height: card.cell

                        Rectangle {
                            anchors.centerIn: parent
                            width: card.cell * 0.86
                            height: width
                            radius: width / 2
                            visible: day.today
                            color: M3.primary
                        }
                        MText {
                            anchors.centerIn: parent
                            role: "bodyMedium"
                            text: day.when.getDate()
                            color: day.today ? M3.primaryContent : M3.surfaceContent
                            opacity: day.inMonth ? 1 : 0.35
                            font.weight: day.today ? Font.Bold : Font.Normal
                        }
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }
}
