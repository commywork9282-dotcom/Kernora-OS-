/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami

Kirigami.Icon {
    property int size: 40
    property string name

    implicitWidth: size
    implicitHeight: size
    source: name.length > 0 ? name : "application-x-executable"
    fallback: "application-x-executable"
    isMask: false
}
