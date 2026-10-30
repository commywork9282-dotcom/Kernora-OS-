/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kernora.m3
import "widgets.js" as Widgets

Item {
    id: card

    required property var model
    required property int index
    property Item explorer
    property bool shown
    property int slot: -1
    property real spacing: 12
    property var pendingUninstalls: []

    readonly property string pluginName: model.pluginName
    readonly property string title: model.name
    readonly property bool kernora: pluginName.startsWith(Widgets.kernoraPrefix)
    readonly property var spec: Widgets.find(pluginName)
    readonly property bool pendingUninstall: pendingUninstalls.indexOf(pluginName) > -1

    visible: shown && slot >= 0
    enabled: model.isSupported
    opacity: pendingUninstall ? 0.6 : (enabled ? 1 : 0.38)
    x: (slot % 2) * (width + spacing)
    y: Math.floor(slot / 2) * (height + spacing)

    Accessible.role: Accessible.Button
    Accessible.name: model.name
    Accessible.description: model.description

    Kirigami.ShadowedRectangle {
        id: cardSurface
        readonly property var shadowSpec: M3.elevationOf("card")
        anchors.fill: parent
        radius: M3.classic ? M3.cornerCard : 24
        color: !M3.classic ? M3.surfaceContainerHigh : M3.dark ? M3.surfaceContainerHighest : M3.surfaceContainerLowest
        shadow.size: M3.classic ? shadowSpec.blur * 2 : 0
        shadow.yOffset: M3.classic ? shadowSpec.offset : 0
        shadow.color: Qt.rgba(0, 0, 0, shadowSpec.opacity)

        MStateLayer {
            radius: cardSurface.radius
            hovered: cardHover.hovered
            pressed: cardTap.pressed
            dragged: cardDrag.active
            pressPoint: Qt.point(cardTap.mouseX, cardTap.mouseY)
        }
    }

    Rectangle {
        id: stage
        x: 8
        y: 8
        width: parent.width - 16
        height: 132
        radius: M3.classic ? M3.cornerCardInner : cardSurface.radius - 8
        color: M3.classic ? M3.withAlpha(M3.surfaceContent, M3.dark ? 0.06 : 0.04) : M3.surfaceContainerLowest

        Loader {
            anchors.fill: parent
            active: card.visible
            sourceComponent: card.kernora ? kernoraPreview : otherPreview
        }

        Component {
            id: kernoraPreview

            WidgetPreview {
                kind: card.pluginName.slice(Widgets.kernoraPrefix.length)
                icon: card.model.decoration
            }
        }

        Component {
            id: otherPreview

            OtherPreview {
                spec: card.spec
                icon: card.model.decoration
            }
        }

        Rectangle {
            id: badge
            readonly property bool removing: badgeHover.hovered && !cardDrag.active
            visible: card.model.running > 0
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 8
            height: 28
            width: Math.max(28, badgeRow.implicitWidth + 14)
            radius: 14
            color: removing ? M3.inverseSurface : M3.primary

            Accessible.role: Accessible.Button
            Accessible.name: i18nd("plasma_shell_org.kde.plasma.desktop", "Remove all instances")

            Row {
                id: badgeRow
                anchors.centerIn: parent
                spacing: 2

                MIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 18
                    source: badge.removing ? "window-close" : "checkmark"
                    color: badge.removing ? M3.inverseOnSurface : M3.primaryContent
                }
                MText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: card.model.running > 1
                    role: "labelMedium"
                    text: card.model.running
                    color: badge.removing ? M3.inverseOnSurface : M3.primaryContent
                }
            }

            HoverHandler {
                id: badgeHover
                margin: 6
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: card.explorer.removeInstances(card.pluginName)
            }
        }

        MIconButton {
            visible: card.model.local
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 2
            icon: card.pendingUninstall ? "edit-undo" : "edit-delete"
            text: card.pendingUninstall ? i18nd("plasma_shell_org.kde.plasma.desktop", "Undo uninstall")
                                        : i18ndc("plasma_shell_org.kde.plasma.desktop", "@info:tooltip uninstall a widget", "Uninstall")
            onClicked: card.explorer.toggleUninstall(card.pluginName)
        }
    }

    ColumnLayout {
        anchors.top: stage.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 14
        anchors.topMargin: 12
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                implicitWidth: 24
                implicitHeight: 24
                radius: 12
                color: M3.primaryContainer

                MIcon {
                    anchors.centerIn: parent
                    visible: !!card.spec
                    size: 16
                    source: card.spec ? card.spec.icon : ""
                    color: M3.primaryContainerContent
                }
                Kirigami.Icon {
                    anchors.centerIn: parent
                    visible: !card.spec
                    implicitWidth: 16
                    implicitHeight: 16
                    source: card.model.decoration
                    animated: false
                }
            }
            MText {
                Layout.fillWidth: true
                role: "titleSmall"
                text: card.model.name
                elide: Text.ElideRight
            }
        }
        MText {
            Layout.fillWidth: true
            role: "bodySmall"
            text: card.model.isSupported ? card.model.description : card.model.unsupportedMessage
            color: M3.surfaceVariantContent
            wrapMode: Text.Wrap
            elide: Text.ElideRight
            maximumLineCount: 3
        }
    }

    HoverHandler {
        id: cardHover
        cursorShape: Qt.PointingHandCursor
    }

    MouseArea {
        id: cardTap
        anchors.fill: parent
        z: -1
        onClicked: card.explorer.addApplet(card.pluginName)
    }

    WidgetDrag {
        id: cardDrag
        anchors.fill: parent
        z: -2
        enabled: !card.pendingUninstall
        pluginName: card.pluginName
        preview: stage
        onStarted: card.explorer.draggingWidget = true
        onFinished: card.explorer.draggingWidget = false
    }
}
