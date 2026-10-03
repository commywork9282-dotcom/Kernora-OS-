/*
    SPDX-FileCopyrightText: 2018 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kernora.m3

Rectangle {
    id: badgeRect

    property alias text: label.text
    property alias textColor: label.color
    property int number: 0

    implicitHeight: 16
    implicitWidth: Math.max(height, Math.ceil(label.implicitWidth) + 8)
    width: implicitWidth

    radius: height / 2
    color: M3.error

    Text {
        id: label
        anchors.centerIn: parent
        color: M3.errorContent
        font.family: M3.typeface
        font.pixelSize: Math.max(9, Math.round(badgeRect.height * 0.7))
        font.weight: Font.Medium
        renderType: Text.QtRendering
        text: {
            if (badgeRect.number < 0) {
                return i18nc("Invalid number of new messages, overlay, keep short", "—");
            } else if (badgeRect.number > 999) {
                return "999+";
            } else {
                return badgeRect.number.toLocaleString(Qt.locale(), 'f', 0);
            }
        }
        textFormat: Text.PlainText
    }
}
