/*
    SPDX-FileCopyrightText: 2026 Kernora Developers
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

QtObject {
    id: catalog

    readonly property var categories: [
        { id: "account", title: i18n("Account"), subtitle: i18n("Name, picture, password"), icon: "user-identity", accent: 0, page: "AccountPage.qml" },
        { id: "network", title: i18n("Network & internet"), subtitle: i18n("Wi-Fi, wired, airplane mode, VPN"), icon: "preferences-system-network", accent: 0, page: "NetworkPage.qml" },
        { id: "bluetooth", title: i18n("Bluetooth"), subtitle: i18n("Pairing, connected devices"), icon: "preferences-system-bluetooth", accent: 0, page: "BluetoothPage.qml" },
        { id: "display", title: i18n("Display & brightness"), subtitle: i18n("Brightness, Night Light, resolution, scale"), icon: "preferences-desktop-display", accent: 1, page: "DisplayPage.qml" },
        { id: "sound", title: i18n("Sound"), subtitle: i18n("Volume, output, microphone"), icon: "preferences-desktop-sound", accent: 1, page: "SoundPage.qml" },
        { id: "notifications", title: i18n("Notifications"), subtitle: i18n("Do Not Disturb, pop-ups, history"), icon: "preferences-desktop-notification", accent: 4, page: "NotificationsPage.qml" },
        { id: "appearance", title: i18n("Wallpaper & style"), subtitle: i18n("Dark theme, wallpaper, text size"), icon: "preferences-desktop-wallpaper", accent: 5, page: "AppearancePage.qml" },
        { id: "apps", title: i18n("Apps"), subtitle: i18n("Default apps, startup apps"), icon: "view-app-grid", accent: 2, page: "AppsPage.qml" },
        { id: "power", title: i18n("Battery & power"), subtitle: i18n("Power mode, screen timeout, sleep"), icon: "preferences-system-power-management", accent: 3, page: "PowerPage.qml" },
        { id: "input", title: i18n("Keyboard, mouse & touchpad"), subtitle: i18n("Layouts, pointer speed, scrolling"), icon: "input-keyboard", accent: 2, page: "InputPage.qml" },
        { id: "accessibility", title: i18n("Accessibility"), subtitle: i18n("Zoom, larger text, motion, keys"), icon: "preferences-desktop-accessibility", accent: 5, page: "AccessibilityPage.qml" },
        { id: "privacy", title: i18n("Security & privacy"), subtitle: i18n("Screen lock, file search, history"), icon: "preferences-security", accent: 4, page: "PrivacyPage.qml" },
        { id: "system", title: i18n("System"), subtitle: i18n("Language, date & time, updates, storage"), icon: "applications-system", accent: 3, page: "SystemPage.qml" },
        { id: "about", title: i18n("About Kernora"), subtitle: i18n("Device name, hardware, legal"), icon: "help-about", accent: 0, page: "AboutPage.qml" }
    ]

    function category(id: string): var {
        return categories.find(c => c.id === id) || null;
    }

    readonly property var searchEntries: {
        const rows = [
            [i18n("Wi-Fi"), "network", "", i18n("wireless network hotspot internet connect password")],
            [i18n("Airplane mode"), "network", "", i18n("flight offline radio")],
            [i18n("Wired network"), "network", "", i18n("ethernet cable lan")],
            [i18n("VPN"), "network", "", i18n("virtual private network tunnel")],
            [i18n("Proxy and advanced network settings"), "network", "", i18n("ip dns proxy static")],
            [i18n("Pair a new device"), "bluetooth", "BluetoothPairPage.qml", i18n("bluetooth headphones speaker mouse keyboard add")],
            [i18n("Brightness"), "display", "", i18n("screen backlight dim")],
            [i18n("Night Light"), "display", "", i18n("blue light warm colour temperature evening")],
            [i18n("Resolution"), "display", "", i18n("screen monitor size pixels")],
            [i18n("Refresh rate"), "display", "", i18n("hz frequency monitor")],
            [i18n("Scale"), "display", "", i18n("zoom size hidpi display scaling")],
            [i18n("Orientation"), "display", "", i18n("rotate portrait landscape")],
            [i18n("Volume"), "sound", "", i18n("loud quiet mute speaker")],
            [i18n("Output device"), "sound", "", i18n("speakers headphones hdmi")],
            [i18n("Microphone"), "sound", "", i18n("input record mic")],
            [i18n("App volume"), "sound", "", i18n("mixer applications streams")],
            [i18n("Do Not Disturb"), "notifications", "", i18n("quiet silence focus")],
            [i18n("Notification history"), "notifications", "", i18n("popups list")],
            [i18n("Dark theme"), "appearance", "", i18n("light dark mode colour scheme night")],
            [i18n("Wallpaper"), "appearance", "", i18n("background picture desktop live shapes")],
            [i18n("Text size"), "appearance", "", i18n("font size bigger smaller")],
            [i18n("Animations"), "appearance", "", i18n("speed effects motion")],
            [i18n("Default apps"), "apps", "DefaultAppsPage.qml", i18n("browser mail files open with association")],
            [i18n("Startup apps"), "apps", "AutostartPage.qml", i18n("autostart login launch")],
            [i18n("Power mode"), "power", "", i18n("performance balanced power saver profile")],
            [i18n("Screen timeout"), "power", "", i18n("dim turn off display idle")],
            [i18n("Sleep"), "power", "", i18n("suspend idle lid power button")],
            [i18n("Battery"), "power", "", i18n("charge percentage")],
            [i18n("Keyboard layouts"), "input", "", i18n("language input switch keymap")],
            [i18n("Key repeat"), "input", "", i18n("delay rate typing")],
            [i18n("Pointer speed"), "input", "", i18n("mouse acceleration sensitivity")],
            [i18n("Natural scrolling"), "input", "", i18n("reverse scroll direction touchpad")],
            [i18n("Tap to click"), "input", "", i18n("touchpad tapping")],
            [i18n("Primary button"), "input", "", i18n("left handed mouse")],
            [i18n("Zoom"), "accessibility", "", i18n("magnifier enlarge screen")],
            [i18n("Reduce motion"), "accessibility", "", i18n("animations off")],
            [i18n("Sticky keys"), "accessibility", "", i18n("modifier keys shift")],
            [i18n("Cursor size"), "accessibility", "", i18n("pointer large mouse")],
            [i18n("Screen lock"), "privacy", "", i18n("lock password idle security")],
            [i18n("File search"), "privacy", "", i18n("indexing baloo search files")],
            [i18n("Recent files"), "privacy", "", i18n("history clear activity")],
            [i18n("Password"), "account", "", i18n("change password login")],
            [i18n("Account picture"), "account", "", i18n("avatar photo face user")],
            [i18n("Name"), "account", "", i18n("full name user")],
            [i18n("Date & time"), "system", "DateTimePage.qml", i18n("clock time zone automatic 24-hour")],
            [i18n("Language & region"), "system", "LanguagePage.qml", i18n("language translation locale formats region")],
            [i18n("Software updates"), "system", "UpdatesPage.qml", i18n("upgrade packages install security")],
            [i18n("Storage"), "system", "StoragePage.qml", i18n("disk space free trash")],
            [i18n("More settings"), "system", "ModulesPage.qml", i18n("advanced kde modules printers shortcuts fonts")],
            [i18n("Device name"), "about", "", i18n("hostname computer name")],
            [i18n("System information"), "about", "", i18n("version hardware processor memory graphics kernel")],
            [i18n("Legal information"), "about", "LegalPage.qml", i18n("licenses copyright authors credits open source")]
        ];
        const entries = [];
        for (const c of categories) {
            entries.push({ title: c.title, section: "", category: c.id, page: "", icon: c.icon, accent: c.accent, keywords: c.subtitle });
        }
        for (const row of rows) {
            const c = category(row[1]);
            entries.push({ title: row[0], section: c.title, category: row[1], page: row[2], icon: c.icon, accent: c.accent, keywords: row[3] });
        }
        return entries;
    }

    readonly property var modules: ({
        "kcm_networkmanagement": ["network", ""],
        "kcm_proxy": ["network", ""],
        "kcm_bluetooth": ["bluetooth", ""],
        "kcm_kscreen": ["display", ""],
        "kcm_nightlight": ["display", ""],
        "kcm_nightcolor": ["display", ""],
        "kcm_pulseaudio": ["sound", ""],
        "kcm_notifications": ["notifications", ""],
        "kcm_colors": ["appearance", ""],
        "kcm_lookandfeel": ["appearance", ""],
        "kcm_wallpaper": ["appearance", ""],
        "kcm_style": ["appearance", ""],
        "kcm_fonts": ["appearance", ""],
        "kcm_icons": ["appearance", ""],
        "kcm_desktoptheme": ["appearance", ""],
        "kcm_cursortheme": ["accessibility", ""],
        "kcm_componentchooser": ["apps", "DefaultAppsPage.qml"],
        "kcm_filetypes": ["apps", "DefaultAppsPage.qml"],
        "kcm_autostart": ["apps", "AutostartPage.qml"],
        "kcm_powerdevilprofilesconfig": ["power", ""],
        "powerdevilprofilesconfig": ["power", ""],
        "kcm_energyinfo": ["power", ""],
        "kcm_keyboard": ["input", ""],
        "kcm_mouse": ["input", ""],
        "kcm_touchpad": ["input", ""],
        "kcm_access": ["accessibility", ""],
        "kcm_screenlocker": ["privacy", ""],
        "kcm_baloofile": ["privacy", ""],
        "kcm_recentFiles": ["privacy", ""],
        "kcm_users": ["account", ""],
        "kcm_clock": ["system", "DateTimePage.qml"],
        "kcm_regionandlang": ["system", "LanguagePage.qml"],
        "kcm_updates": ["system", "UpdatesPage.qml"],
        "kcm_about-distro": ["about", ""],
        "kcm_landingpage": ["network", ""]
    })

    function resolve(argument: string): var {
        let name = argument.replace(/^.*\//, "").replace(/\.desktop$/, "");
        if (categories.some(c => c.id === name)) {
            return { category: name, page: "" };
        }
        if (!name.startsWith("kcm_") && modules["kcm_" + name]) {
            name = "kcm_" + name;
        }
        const target = modules[name];
        return target ? { category: target[0], page: target[1] } : null;
    }
}
