/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma Singleton

import QtQuick

QtObject {
    property string screen: ""
    property real scrim: 0

    signal openRequested(string screen)
    signal closeRequested()

    function requestOpen(screen: string): void {
        openRequested(screen);
    }

    function requestClose(): void {
        closeRequested();
    }
}
