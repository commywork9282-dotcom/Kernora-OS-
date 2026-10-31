# SPDX-FileCopyrightText: 2026 Kernora Developers
# SPDX-License-Identifier: GPL-2.0-or-later

ecm_add_qml_module(kernorasystem URI "org.kernora.system" VERSION 1.0 GENERATE_PLUGIN_SOURCE)

target_sources(kernorasystem PRIVATE
    accounts.cpp accounts.h
    android.cpp android.h
    apk.cpp apk.h
    appearance.cpp appearance.h
    autostart.cpp autostart.h
    config.cpp config.h
    dbus.cpp dbus.h
    defaultapps.cpp defaultapps.h
    displays.cpp displays.h
    files.cpp files.h
    licenses.cpp licenses.h
    locales.cpp locales.h
    mpris.cpp mpris.h
    places.cpp places.h
    process.cpp process.h
    quickshare.cpp quickshare.h
    screenshot.cpp screenshot.h
    systeminfo.cpp systeminfo.h
    updates.cpp updates.h
)

target_link_libraries(kernorasystem PRIVATE
    Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::DBus Qt6::Widgets Qt6::Svg
    KF6::Archive KF6::ConfigCore KF6::CoreAddons KF6::I18n KF6::KIOCore KF6::KIOFileWidgets KF6::KIOGui KF6::KIOWidgets KF6::Service
    KF6::Screen
    PK::packagekitqt6
    PkgConfig::LIBCRYPT
)

ecm_finalize_qml_module(kernorasystem DESTINATION ${KDE_INSTALL_QMLDIR})
target_compile_definitions(kernorasystem PRIVATE TRANSLATION_DOMAIN="kernora-system"
    KERNORA_LIBEXECDIR="${KDE_INSTALL_FULL_LIBEXECDIR}")
