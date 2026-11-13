/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.plasma.private.batterymonitor

PowerProfilesControl {
    readonly property bool saver: isPowerProfileDaemonInstalled && activeProfile === "power-saver"
}
