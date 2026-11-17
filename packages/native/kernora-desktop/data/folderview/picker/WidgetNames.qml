/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQml

QtObject {
    readonly property var apps: ({
        "battery": i18nd("kernora-ui", "Battery"),
        "calendar": i18nd("kernora-ui", "Calendar"),
        "clock": i18nd("kernora-ui", "Clock"),
        "kernora": "Kernora",
        "player": i18nd("kernora-ui", "Media Player"),
        "notes": i18nd("kernora-ui", "Notes"),
        "photos": i18nd("kernora-ui", "Photos"),
        "taskmanager": i18nd("kernora-ui", "Task Manager"),
        "weather": i18nd("kernora-ui", "Weather")
    })
    readonly property var variants: ({
        "org.kernora.widget.clock#analog": i18nd("kernora-ui", "Analog clock"),
        "org.kernora.widget.clock#digital": i18nd("kernora-ui", "Digital clock"),
        "org.kernora.widget.clock#stacked": i18nd("kernora-ui", "Stacked clock"),
        "org.kernora.widget.weather#current": i18nd("kernora-ui", "Current weather"),
        "org.kernora.widget.weather#forecast": i18nd("kernora-ui", "Forecasted weather"),
        "org.kernora.widget.photo#cookie9": i18nd("kernora-ui", "Cookie"),
        "org.kernora.widget.photo#sunny": i18nd("kernora-ui", "Star"),
        "org.kernora.widget.photo#flower": i18nd("kernora-ui", "Flower"),
        "org.kernora.widget.photo#circle": i18nd("kernora-ui", "Circle"),
        "org.kernora.widget.photo#square": i18nd("kernora-ui", "Square"),
        "org.kernora.widget.photo#pill": i18nd("kernora-ui", "Pill"),
        "org.kernora.widget.photo#fill": i18nd("kernora-ui", "Full size")
    })
}
