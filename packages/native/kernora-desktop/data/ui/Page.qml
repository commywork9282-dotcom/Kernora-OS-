/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kernora.m3

Item {
    id: root

    property string title
    property string subtitle
    property bool canGoBack: false
    property int maximumContentWidth: 760
    property real cornerRadius: 0
    property alias flickable: flick
    property Component actions
    property Component hero
    default property alias content: body.data
    readonly property real contentWidth: Math.min(width - 48, maximumContentWidth)

    signal back()

    clip: true

    Flickable {
        id: flick

        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight + 48
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        Column {
            id: column

            x: (flick.width - root.contentWidth) / 2
            y: 28
            width: root.contentWidth
            spacing: 24

            Loader {
                width: parent.width
                active: root.hero !== null
                visible: active
                sourceComponent: root.hero
            }

            RowLayout {
                id: header
                width: parent.width
                spacing: 8

                IconButton {
                    visible: root.canGoBack
                    iconName: Qt.application.layoutDirection === Qt.RightToLeft ? "go-next" : "go-previous"
                    text: (typeof i18nd === "function" ? i18nd("kernora-ui", "Back") : qsTr("Back"))
                    onClicked: root.back()
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: 6
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    MText {
                        id: bigTitle
                        Layout.fillWidth: true
                        role: "headlineLarge"
                        text: root.title
                        wrapMode: Text.Wrap
                        elide: Text.ElideNone
                    }
                    MText {
                        Layout.fillWidth: true
                        role: "bodyLarge"
                        text: root.subtitle
                        visible: text.length > 0
                        color: M3.surfaceVariantContent
                        wrapMode: Text.Wrap
                        lineHeightMode: Text.ProportionalHeight
                        lineHeight: 1.1
                    }
                }

                Loader {
                    Layout.alignment: Qt.AlignTop
                    active: root.actions !== null
                    visible: active
                    sourceComponent: root.actions
                }
            }

            Column {
                id: body
                width: parent.width
                spacing: 28
            }
        }
    }

    MScrollIndicator {
        flickable: flick
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: compactBar.height
    }

    Rectangle {
        id: compactBar

        readonly property bool shown: flick.contentY > header.y + bigTitle.height

        anchors.left: parent.left
        anchors.right: parent.right
        height: 56
        topLeftRadius: root.cornerRadius
        topRightRadius: root.cornerRadius
        color: M3.surfaceContainer
        opacity: shown ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation { duration: M3.durationShort4; easing.type: Easing.Bezier; easing.bezierCurve: M3.easingStandard }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 8
            IconButton {
                visible: root.canGoBack
                iconName: Qt.application.layoutDirection === Qt.RightToLeft ? "go-next" : "go-previous"
                text: (typeof i18nd === "function" ? i18nd("kernora-ui", "Back") : qsTr("Back"))
                onClicked: root.back()
            }
            MText {
                Layout.fillWidth: true
                Layout.leftMargin: root.canGoBack ? 0 : 12
                role: "titleLarge"
                text: root.title
            }
            Loader {
                active: root.actions !== null
                visible: active
                sourceComponent: root.actions
            }
        }
    }
}
