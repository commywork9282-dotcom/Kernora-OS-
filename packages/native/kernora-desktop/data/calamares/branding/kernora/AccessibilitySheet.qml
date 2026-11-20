/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import io.calamares.core 1.0
import io.calamares.ui 1.0

import QtQuick
import org.kernora.m3
import org.kernora.ui

Item {
    id: sheet

    signal closed()

    readonly property var sizes: [
        { points: 10.5, label: qsTr("Default") },
        { points: 12, label: qsTr("Large") },
        { points: 13.5, label: qsTr("Larger") },
        { points: 15, label: qsTr("Largest") }
    ]
    property real points: 10.5
    property bool reduceMotion: false

    readonly property bool wide: width >= 960
    readonly property real margin: wide ? Math.round(Math.max(40, Math.min(72, width * 0.05))) : 24
    readonly property real topSpace: Math.round(Math.max(88, Math.min(136, height * 0.15)))
    readonly property real paneWidth: wide ? Math.round(width / 2 - margin - 24) : width - 2 * margin
    readonly property real bottomSpace: Math.round(Math.max(24, Math.min(48, height * 0.053)))

    function symbol(name: string): url {
        return Qt.resolvedUrl("symbols/" + name + "_24px.svg");
    }

    function store(): void {
        Global.insert("kernoraAccessibility", JSON.stringify({ fontSize: sheet.points, reduceMotion: sheet.reduceMotion }));
    }

    function setPoints(value: real): void {
        sheet.points = value;
        ViewManager.textScale = value / 10.5;
        store();
    }

    function setReduceMotion(on: bool): void {
        sheet.reduceMotion = on;
        store();
    }

    function open(): void {
        sheet.visible = true;
        back.forceActiveFocus();
    }

    function close(): void {
        sheet.visible = false;
        sheet.closed();
    }

    visible: false

    Keys.onEscapePressed: sheet.close()

    Rectangle {
        anchors.fill: parent
        color: M3.surface
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
    }

    Item {
        id: back

        x: Math.round(sheet.margin / 2 - 8)
        y: x
        width: 48
        height: 48
        activeFocusOnTab: true

        Accessible.role: Accessible.Button
        Accessible.name: qsTr("Back")
        Keys.onReturnPressed: sheet.close()
        Keys.onSpacePressed: sheet.close()

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: M3.surfaceContainerHigh
        }

        MIcon {
            anchors.centerIn: parent
            size: 24
            source: sheet.symbol("arrow_back")
            color: M3.surfaceContent
        }

        MStateLayer {
            anchors.fill: parent
            radius: width / 2
            color: M3.surfaceContent
            hovered: backMouse.containsMouse
            pressed: backMouse.pressed
            focused: back.activeFocus
        }

        MouseArea {
            id: backMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sheet.close()
        }
    }

    Column {
        id: header

        x: sheet.margin
        y: sheet.topSpace
        width: sheet.paneWidth - (sheet.wide ? 16 : 0)

        MIcon {
            size: 40
            source: sheet.symbol("accessibility_new")
            color: M3.primary
        }

        Item {
            width: 1
            height: 28
        }

        MText {
            width: parent.width
            role: "displaySmall"
            text: qsTr("Accessibility")
            wrapMode: Text.Wrap
            elide: Text.ElideNone
            lineHeightMode: Text.ProportionalHeight
            lineHeight: 1.1
        }

        Item {
            width: 1
            height: 20
        }

        MText {
            width: parent.width
            role: "bodyLarge"
            text: qsTr("Make text bigger or reduce motion. Kernora keeps these after setup, and Settings › Accessibility has zoom, colour filters and more.")
            color: M3.surfaceVariantContent
            wrapMode: Text.Wrap
            elide: Text.ElideNone
            lineHeightMode: Text.ProportionalHeight
            lineHeight: 1.25
        }
    }

    Flickable {
        id: area

        x: sheet.wide ? Math.round(sheet.width / 2 + 24) : sheet.margin
        y: sheet.wide ? sheet.topSpace : header.y + header.height + 32
        width: sheet.paneWidth
        height: Math.max(0, done.y - y - 24)
        contentHeight: options.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: options

            width: area.width
            spacing: 2

            MText {
                x: 4
                height: 36
                role: "titleSmall"
                text: qsTr("Text size")
                color: M3.primary
                verticalAlignment: Text.AlignTop
            }

            Repeater {
                model: sheet.sizes

                delegate: Item {
                    id: row

                    required property int index
                    required property var modelData
                    readonly property bool selected: Math.abs(sheet.points - modelData.points) < 0.01
                    readonly property bool first: index === 0
                    readonly property bool last: index === sheet.sizes.length - 1

                    width: options.width
                    height: Math.max(64, label.implicitHeight + 28)
                    activeFocusOnTab: true

                    Accessible.role: Accessible.RadioButton
                    Accessible.name: modelData.label
                    Accessible.checked: selected
                    Keys.onReturnPressed: sheet.setPoints(modelData.points)
                    Keys.onSpacePressed: sheet.setPoints(modelData.points)

                    Rectangle {
                        anchors.fill: parent
                        color: row.selected ? M3.secondaryContainer : M3.surfaceContainerHigh
                        topLeftRadius: row.first ? 24 : 6
                        topRightRadius: row.first ? 24 : 6
                        bottomLeftRadius: row.last ? 24 : 6
                        bottomRightRadius: row.last ? 24 : 6
                    }

                    MText {
                        id: label
                        x: 24
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 80
                        role: "bodyLarge"
                        font.pixelSize: Math.round(M3.bodyLarge.pixelSize * row.modelData.points / sheet.points)
                        lineHeightMode: Text.ProportionalHeight
                        lineHeight: 1
                        text: row.modelData.label
                        color: row.selected ? M3.secondaryContainerContent : M3.surfaceContent
                    }

                    MIcon {
                        visible: row.selected
                        anchors.right: parent.right
                        anchors.rightMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        size: 24
                        source: sheet.symbol("check")
                        color: M3.secondaryContainerContent
                    }

                    MStateLayer {
                        anchors.fill: parent
                        radius: 6
                        color: M3.surfaceContent
                        hovered: rowMouse.containsMouse
                        pressed: rowMouse.pressed
                        focused: row.activeFocus
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sheet.setPoints(row.modelData.points)
                    }
                }
            }

            Item {
                width: 1
                height: 24
            }

            Group {
                width: options.width

                ListItem {
                    title: qsTr("Reduce motion")
                    subtitle: qsTr("Turn off animations everywhere")
                    icon: "preferences-desktop-effects"
                    iconStyle: "plain"
                    checkable: true
                    checked: sheet.reduceMotion
                    onToggled: on => sheet.setReduceMotion(on)
                }
            }
        }
    }

    MButton {
        id: done

        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: sheet.margin
        anchors.bottomMargin: sheet.bottomSpace
        variant: "filled"
        text: qsTr("Done")
        height: 56
        width: Math.max(implicitWidth + 16, 148)
        onClicked: sheet.close()
    }
}
