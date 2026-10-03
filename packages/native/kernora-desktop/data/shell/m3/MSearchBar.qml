/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: root

    property alias text: input.text
    property alias input: input
    property string placeholderText

    signal accepted()
    signal navigateDown()
    signal navigateUp()

    implicitHeight: 56
    implicitWidth: 360

    function clear(): void {
        input.clear();
    }

    Kirigami.ShadowedRectangle {
        id: container
        anchors.fill: parent
        readonly property var shadowSpec: M3.elevationOf("field")
        radius: M3.radius("field", height)
        color: M3.classic ? (M3.dark ? M3.surfaceContainerHighest : M3.surfaceContainerLowest) : M3.surfaceContainerHigh
        border.width: input.activeFocus && !M3.classic ? 2 : 0
        border.color: M3.primary
        shadow.size: shadowSpec.blur * (input.activeFocus ? 2 : 1)
        shadow.yOffset: shadowSpec.offset
        shadow.color: Qt.rgba(0, 0, 0, shadowSpec.opacity)

        MIcon {
            id: leading
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            source: "search"
            color: M3.surfaceVariantContent
        }

        TextInput {
            id: input
            anchors.left: leading.right
            anchors.leftMargin: 16
            anchors.right: clearButton.visible ? clearButton.left : parent.right
            anchors.rightMargin: clearButton.visible ? 4 : 20
            anchors.verticalCenter: parent.verticalCenter
            font: M3.bodyLarge
            color: M3.surfaceContent
            selectionColor: M3.primary
            selectedTextColor: M3.primaryContent
            clip: true
            selectByMouse: true
            renderType: Text.QtRendering

            Keys.onDownPressed: root.navigateDown()
            Keys.onUpPressed: root.navigateUp()
            Keys.onReturnPressed: root.accepted()
            Keys.onEnterPressed: root.accepted()
            Keys.onEscapePressed: event => {
                if (text.length > 0) {
                    clear();
                } else {
                    event.accepted = false;
                }
            }

            MText {
                anchors.verticalCenter: parent.verticalCenter
                role: "bodyLarge"
                text: root.placeholderText
                color: M3.surfaceVariantContent
                visible: input.text.length === 0 && !input.preeditText
            }
        }

        MIconButton {
            id: clearButton
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            icon: "edit-clear"
            text: i18n("Clear search")
            visible: input.text.length > 0
            activeFocusOnTab: false
            onClicked: {
                input.clear();
                input.forceActiveFocus();
            }
        }

        MouseArea {
            anchors.fill: parent
            anchors.rightMargin: clearButton.visible ? clearButton.width + 8 : 0
            cursorShape: Qt.IBeamCursor
            acceptedButtons: Qt.NoButton
        }
    }
}
