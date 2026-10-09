/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18nd("plasma_applet_org.kernora.widget.clock", "Appearance")
        icon: "preferences-desktop-theme"
        source: "ConfigGeneral.qml"
    }
}
