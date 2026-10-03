/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.plasma.private.sessions

SessionManagement {
    function logout(): void { requestLogout(); }
    function reboot(): void { requestReboot(); }
    function shutdown(): void { requestShutdown(); }
}
