/*
    SPDX-FileCopyrightText: 2024 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2014 David Edmundson <davidedmundson@kde.org>
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kernora.m3

Item {
    id: editMode

    property real centerX: Math.round(editModeUi.x + editModeUi.width / 2)
    property real centerY: Math.round(editModeUi.y + editModeUi.height / 2)
    property real roundedRootWidth: Math.round(root.width)
    property real roundedRootHeight: Math.round(root.height)
    property bool open: false

    readonly property real cornerRadius: M3.classic ? M3.cornerCard : 28
    readonly property int toolBarGap: 12

    function tr(text: string): string {
        return i18nd("kernora-ui", text);
    }

    function plain(text: string): string {
        return (text || "").replace(/&(?!&)/g, "").replace(/[.…]+$/, "");
    }

    Component.onCompleted: {
        open = Qt.binding(() => containment.plasmoid.corona.editMode);
    }

    Item {
        anchors.fill: parent
        opacity: editMode.open ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: M3.durationMedium4
                easing.type: Easing.Bezier
                easing.bezierCurve: M3.easingStandard
            }
        }

        MultiEffect {
            source: containment
            anchors.fill: parent
            blurEnabled: true
            blurMax: 64
            blur: 1.0
        }
        Rectangle {
            anchors.fill: parent
            color: M3.surfaceDim
            opacity: 0.78
        }
    }

    Item {
        id: editModeUi

        readonly property real zoomedWidth: Math.round(root.width * containmentParent.scaleFactor)
        readonly property real zoomedHeight: Math.round(root.height * containmentParent.scaleFactor)

        visible: editMode.open || xAnim.running
        x: Math.round(editMode.open ? editModeRect.x + editModeRect.width / 2 - zoomedWidth / 2 : 0)
        y: Math.round(editMode.open ? editModeRect.y + editModeRect.height / 2 - zoomedHeight / 2 + (toolBar.height + editMode.toolBarGap) / 2 : 0)
        width: editMode.open ? zoomedWidth : editMode.roundedRootWidth
        height: editMode.open ? zoomedHeight : editMode.roundedRootHeight

        Behavior on x {
            NumberAnimation {
                id: xAnim
                duration: M3.durationLong2
                easing.type: Easing.Bezier
                easing.bezierCurve: M3.easingEmphasized
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: M3.durationLong2
                easing.type: Easing.Bezier
                easing.bezierCurve: M3.easingEmphasized
            }
        }
        Behavior on width {
            NumberAnimation {
                duration: M3.durationLong2
                easing.type: Easing.Bezier
                easing.bezierCurve: M3.easingEmphasized
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: M3.durationLong2
                easing.type: Easing.Bezier
                easing.bezierCurve: M3.easingEmphasized
            }
        }

        Kirigami.ShadowedRectangle {
            anchors.fill: parent
            color: M3.surface
            radius: editMode.open ? editMode.cornerRadius : 0
            shadow.size: 36
            shadow.yOffset: 8
            shadow.color: Qt.rgba(0, 0, 0, M3.dark ? 0.5 : 0.25)

            Behavior on radius {
                NumberAnimation {
                    duration: M3.durationLong2
                }
            }
        }

        MultiEffect {
            anchors.fill: parent
            source: containment
            layer.enabled: true
            layer.smooth: true
            layer.effect: Kirigami.ShadowedTexture {
                width: editMode.roundedRootWidth
                height: editMode.roundedRootHeight
                color: "transparent"
                radius: editMode.open ? editMode.cornerRadius : 0

                Behavior on radius {
                    NumberAnimation {
                        duration: M3.durationLong2
                    }
                }
            }
        }
    }

    Kirigami.ShadowedRectangle {
        id: toolBar

        readonly property var shadowSpec: M3.elevationOf("menu")

        anchors.horizontalCenter: editModeUi.horizontalCenter
        y: Math.max(editModeRect.y + 8, editModeUi.y - height - editMode.toolBarGap)
        width: Math.min(row.implicitWidth + 16, editModeUi.width)
        height: 56
        radius: M3.classic ? M3.cornerCard : height / 2
        color: M3.surfaceContainer
        shadow.size: M3.classic ? shadowSpec.blur : 18
        shadow.yOffset: M3.classic ? shadowSpec.offset : 4
        shadow.color: Qt.rgba(0, 0, 0, M3.dark ? 0.4 : 0.16)
        visible: editMode.open || toolBarFade.running
        opacity: editMode.open ? 1 : 0
        scale: editMode.open ? 1 : 0.9

        Behavior on opacity {
            NumberAnimation {
                id: toolBarFade
                duration: M3.durationMedium2
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: M3.durationMedium4
                easing.type: Easing.Bezier
                easing.bezierCurve: M3.easingEmphasizedDecelerate
            }
        }

        LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
        LayoutMirroring.childrenInherit: true

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 8

            MButton {
                readonly property QtObject qAction: containment?.plasmoid.internalAction("add widgets") || null
                variant: "tonal"
                icon: "preferences-desktop-widgets"
                text: i18nd("plasma_shell_org.kde.plasma.desktop", "Widgets")
                Accessible.description: editMode.plain(qAction?.text)
                onClicked: qAction.trigger()
            }
            MButton {
                readonly property QtObject qAction: containment?.plasmoid.internalAction("configure") || null
                visible: qAction !== null
                variant: "tonal"
                icon: "preferences-desktop-wallpaper"
                text: editMode.tr("Wallpaper")
                Accessible.description: editMode.plain(qAction?.text)
                onClicked: qAction.trigger()
            }
            MButton {
                id: addPanelButton
                readonly property QtObject qAction: containment?.plasmoid.corona.action("add panel") || null
                variant: "tonal"
                icon: "list-add"
                text: editMode.plain(qAction?.text)
                Accessible.role: Accessible.ButtonMenu
                onClicked: containment.plasmoid.corona.showAddPanelContextMenu(mapToGlobal(0, height + 8))
            }
            MButton {
                readonly property QtObject qAction: containment?.plasmoid.corona.action("manage-containments") || null
                visible: qAction?.visible || false
                variant: "tonal"
                icon: "configure"
                text: editMode.plain(qAction?.text)
                onClicked: qAction.trigger()
            }
            MIconButton {
                id: moreButton
                visible: Kirigami.Settings.hasTransientTouchInput || Kirigami.Settings.tabletMode
                icon: "overflow-menu"
                text: i18ndc("plasma_shell_org.kde.plasma.desktop", "@action:button", "More")
                onClicked: containment.openContextMenu(mapToGlobal(0, height))
            }
            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 24
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                color: M3.outlineVariant
            }
            MButton {
                variant: "filled"
                icon: "checkmark"
                text: editMode.tr("Done")
                Accessible.description: i18nd("plasma_shell_org.kde.plasma.desktop", "Exit Edit Mode")
                onClicked: containment.plasmoid.corona.editMode = false
            }
        }
    }
}
