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

    switchWidth: Plasmoid.configuration.placed ? 0 : 239
    switchHeight: Plasmoid.configuration.placed ? 0 : 219

    Timer {
        running: !Plasmoid.configuration.placed
        interval: 2000
        onTriggered: Plasmoid.configuration.placed = true
    }

    toolTipMainText: i18n("Note")
    toolTipSubText: ""

    fullRepresentation: WidgetSurface {
        id: card
        Layout.preferredWidth: 240
        Layout.preferredHeight: 220
        Layout.minimumWidth: 140
        Layout.minimumHeight: 120
        color: M3.tertiaryContainer

        Timer {
            id: save
            interval: 600
            onTriggered: Plasmoid.configuration.text = editor.text
        }

        Flickable {
            id: scroller
            anchors.fill: parent
            anchors.margins: 20
            contentHeight: editor.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            TextEdit {
                id: editor
                width: scroller.width
                wrapMode: TextEdit.Wrap
                text: Plasmoid.configuration.text
                color: M3.tertiaryContainerContent
                font: M3.bodyLarge
                selectByMouse: true
                selectionColor: M3.tertiary
                selectedTextColor: M3.tertiaryContent
                onTextChanged: save.restart()
                onCursorRectangleChanged: {
                    if (cursorRectangle.y + cursorRectangle.height > scroller.contentY + scroller.height) {
                        scroller.contentY = cursorRectangle.y + cursorRectangle.height - scroller.height;
                    } else if (cursorRectangle.y < scroller.contentY) {
                        scroller.contentY = cursorRectangle.y;
                    }
                }

                Text {
                    visible: editor.text.length === 0 && !editor.activeFocus
                    text: i18n("Write a note")
                    color: M3.tertiaryContainerContent
                    opacity: 0.6
                    font: M3.bodyLarge
                }
            }
        }
    }
}
