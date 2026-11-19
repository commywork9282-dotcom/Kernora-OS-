/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import io.calamares.ui 1.0

import QtQuick
import org.kernora.m3

Item {
    id: page

    property string icon
    property string title
    property string description
    property string primaryText: page.plain(ViewManager.nextLabel)
    property bool primaryEnabled: ViewManager.nextEnabled
    property var primaryAction: null
    property string secondaryText
    property var secondaryAction: null
    property bool showBack: ViewManager.backEnabled
    property bool showButtons: true
    default property alias content: area.data
    property alias below: extra.data

    readonly property bool wide: width >= 960
    readonly property real margin: wide ? Math.round(Math.max(40, Math.min(72, width * 0.05))) : 24
    readonly property real topSpace: Math.round(Math.max(88, Math.min(136, height * 0.15)))
    readonly property real buttonsHeight: 56
    readonly property real bottomSpace: Math.round(Math.max(24, Math.min(48, height * 0.053)))
    readonly property real paneWidth: wide ? Math.round(width / 2 - margin - 24) : width - 2 * margin
    readonly property real areaTop: wide ? topSpace : header.y + header.height + 24
    readonly property real areaHeight: height - areaTop - buttonsHeight - bottomSpace - 24

    function plain(label: string): string {
        return label.replace(/&(?!&)/g, "").replace(/&&/g, "&");
    }

    function symbol(name: string): url {
        return Qt.resolvedUrl("symbols/" + name + "_24px.svg");
    }

    Rectangle {
        anchors.fill: parent
        color: M3.surface
    }

    Item {
        id: back

        visible: page.showBack
        x: Math.round(page.margin / 2 - 8)
        y: x
        width: 48
        height: 48
        activeFocusOnTab: true

        Accessible.role: Accessible.Button
        Accessible.name: page.plain(ViewManager.backLabel)
        Keys.onReturnPressed: ViewManager.back()
        Keys.onSpacePressed: ViewManager.back()

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: M3.surfaceContainerHigh
        }

        MIcon {
            anchors.centerIn: parent
            size: 24
            source: page.symbol("arrow_back")
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
            onClicked: ViewManager.back()
        }
    }

    Column {
        id: header

        x: page.margin
        y: page.topSpace
        width: page.paneWidth - (page.wide ? 16 : 0)

        MIcon {
            visible: page.icon.length > 0
            size: 40
            source: page.icon.length > 0 ? page.symbol(page.icon) : ""
            color: M3.primary
        }

        Item {
            width: 1
            height: page.icon.length > 0 ? 28 : 0
        }

        MText {
            width: parent.width
            role: "displaySmall"
            text: page.title
            wrapMode: Text.Wrap
            elide: Text.ElideNone
            lineHeightMode: Text.ProportionalHeight
            lineHeight: 1.1
        }

        Item {
            width: 1
            height: page.description.length > 0 ? 20 : 0
        }

        MText {
            visible: page.description.length > 0
            width: parent.width
            role: "bodyLarge"
            text: page.description
            color: M3.surfaceVariantContent
            wrapMode: Text.Wrap
            elide: Text.ElideNone
            lineHeightMode: Text.ProportionalHeight
            lineHeight: 1.25
        }

        Item {
            width: 1
            height: extra.children.length > 0 ? 36 : 0
        }

        Item {
            id: extra
            width: parent.width
            height: childrenRect.height
        }
    }

    Item {
        id: area

        x: page.wide ? Math.round(page.width / 2 + 24) : page.margin
        y: page.areaTop
        width: page.paneWidth
        height: Math.max(0, page.areaHeight)
    }

    Row {
        visible: page.showButtons
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: page.margin
        anchors.bottomMargin: page.bottomSpace
        spacing: 12

        MButton {
            visible: page.secondaryText.length > 0
            variant: "outlined"
            text: page.secondaryText
            height: page.buttonsHeight
            width: Math.max(implicitWidth + 16, 148)
            onClicked: page.secondaryAction ? page.secondaryAction() : ViewManager.back()
        }

        MButton {
            id: primary
            visible: page.primaryText.length > 0
            enabled: page.primaryEnabled
            variant: "filled"
            text: page.primaryText
            height: page.buttonsHeight
            width: Math.max(implicitWidth + 16, 148)
            onClicked: page.primaryAction ? page.primaryAction() : ViewManager.next()
        }
    }
}
