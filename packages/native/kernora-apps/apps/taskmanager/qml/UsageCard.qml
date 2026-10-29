/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kernora.m3
import org.kde.quickcharts as Charts

Rectangle {
    id: card

    property string title
    property string icon
    property string amount
    property string detail
    property string note
    property bool available: true
    property bool percent: true
    property real first: 0
    property real second: NaN
    property string firstLabel
    property string secondLabel
    readonly property bool paired: !isNaN(second)

    Layout.fillWidth: true
    implicitHeight: 248
    radius: M3.classic ? M3.cornerCard : 24
    color: M3.surfaceContainerLow

    Charts.HistoryProxySource {
        id: firstHistory
        source: Charts.SingleValueSource { value: card.first }
        maximumHistory: 60
        interval: 1000
        fillMode: Charts.HistoryProxySource.FillFromStart
    }
    Charts.HistoryProxySource {
        id: secondHistory
        source: Charts.SingleValueSource { value: card.paired ? card.second : 0 }
        maximumHistory: 60
        interval: 1000
        fillMode: Charts.HistoryProxySource.FillFromStart
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MIcon {
                size: 20
                source: card.icon
                color: M3.primary
            }
            MText {
                Layout.fillWidth: true
                role: "titleMedium"
                text: card.title
                elide: Text.ElideRight
            }
            Legend {
                visible: card.paired && card.available
                label: card.firstLabel
                colour: M3.primary
            }
            Legend {
                visible: card.paired && card.available
                label: card.secondLabel
                colour: M3.tertiary
            }
        }
        MText {
            Layout.fillWidth: true
            role: "headlineLarge"
            text: card.amount
            elide: Text.ElideRight
        }
        MText {
            Layout.fillWidth: true
            role: "bodyMedium"
            color: M3.surfaceVariantContent
            text: card.detail
            visible: text.length > 0
            elide: Text.ElideRight
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 8

            Charts.LineChart {
                anchors.fill: parent
                visible: card.available
                smooth: true
                lineWidth: 2
                fillOpacity: 0.18
                direction: Charts.XYChart.ZeroAtEnd
                yRange {
                    from: 0
                    to: 100
                    automatic: !card.percent
                }
                colorSource: Charts.ArraySource {
                    array: card.paired ? [M3.primary, M3.tertiary] : [M3.primary]
                }
                valueSources: card.paired ? [firstHistory, secondHistory] : [firstHistory]
            }
            MText {
                anchors.centerIn: parent
                width: parent.width
                visible: !card.available
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                role: "bodyMedium"
                color: M3.surfaceVariantContent
                text: card.note
            }
        }
    }

    component Legend: RowLayout {
        id: legend
        property string label
        property color colour
        spacing: 6

        Rectangle {
            Layout.preferredWidth: 10
            Layout.preferredHeight: 10
            radius: 5
            color: legend.colour
        }
        MText {
            role: "labelMedium"
            color: M3.surfaceVariantContent
            text: legend.label
        }
    }
}
