/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

MSpring {
    property bool active: false

    dampingRatio: M3.springExpressiveFastDamping
    response: M3.springExpressiveFastResponse

    onActiveChanged: animateTo(active ? 1 : 0)
    Component.onCompleted: jumpTo(active ? 1 : 0)
}
