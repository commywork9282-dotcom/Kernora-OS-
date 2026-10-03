/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import io.calamares.ui 1.0
import io.calamares.core 1.0

import QtQuick
import QtQuick.Layouts
import org.kernora.m3

Rectangle {
    id: sideBar

    color: M3.surfaceContainer
    anchors.fill: parent

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        anchors.topMargin: 20
        spacing: 4

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 20
            implicitWidth: 64
            implicitHeight: 64
            radius: 32
            color: M3.primary
            MIcon {
                anchors.centerIn: parent
                size: 40
                source: "kernora-logo"
                color: M3.primaryContent
            }
        }

        Repeater {
            model: ViewManager

            delegate: Item {
                id: step

                required property int index
                required property string display
                readonly property bool current: index === ViewManager.currentStepIndex
                readonly property bool done: index < ViewManager.currentStepIndex

                Layout.fillWidth: true
                implicitHeight: Math.max(40, label.implicitHeight + 14)

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: step.current ? M3.secondaryContainer : "transparent"
                    Behavior on color { ColorAnimation { duration: M3.durationShort4 } }
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 7
                    anchors.rightMargin: 8
                    spacing: 8

                    Rectangle {
                        implicitWidth: 24
                        implicitHeight: 24
                        radius: 12
                        color: step.done || step.current ? M3.primary : "transparent"
                        border.width: step.done || step.current ? 0 : 1.5
                        border.color: M3.outline
                        MIcon {
                            anchors.centerIn: parent
                            visible: step.done
                            size: 18
                            source: "checkmark"
                            color: M3.primaryContent
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: !step.done
                            text: step.index + 1
                            font: M3.labelMedium
                            color: step.current ? M3.primaryContent : M3.surfaceVariantContent
                        }
                    }
                    MText {
                        id: label
                        Layout.fillWidth: true
                        role: "labelLarge"
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        lineHeightMode: Text.ProportionalHeight
                        lineHeight: 1.0
                        text: step.display
                        color: step.current ? M3.secondaryContainerContent : (step.done ? M3.surfaceContent : M3.surfaceVariantContent)
                    }
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 4
            MText {
                role: "labelMedium"
                text: qsTr("About")
                color: M3.surfaceVariantContent
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    cursorShape: Qt.PointingHandCursor
                    onClicked: debug.about()
                }
            }
            MText {
                visible: debug.enabled
                role: "labelMedium"
                text: " · " + qsTr("Debug")
                color: M3.surfaceVariantContent
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: debug.toggle()
                }
            }
        }
    }
}
