# SPDX-FileCopyrightText: 2026 Kernora Developers
# SPDX-License-Identifier: GPL-2.0-or-later

add_library(kernora-appicons STATIC appicons.cpp appicons.h appiconsync.cpp appiconsync.h)
target_link_libraries(kernora-appicons PUBLIC Qt6::Gui Qt6::DBus KF6::ConfigCore KF6::Service)

add_executable(kernora-update-notifier main.cpp avatarsync.cpp avatarsync.h greetersync.cpp greetersync.h)
target_link_libraries(kernora-update-notifier PRIVATE
    kernora-appicons
    Qt6::Gui Qt6::DBus Qt6::Network
    KF6::ConfigCore KF6::CoreAddons KF6::DBusAddons KF6::I18n KF6::Notifications
    PK::packagekitqt6)
target_compile_definitions(kernora-update-notifier PRIVATE
    TRANSLATION_DOMAIN="kernora-update-notifier"
    KERNORA_APPS_VERSION="${PROJECT_VERSION}")
install(TARGETS kernora-update-notifier ${KDE_INSTALL_TARGETS_DEFAULT_ARGS})

add_executable(kernora-app-icons appiconstool.cpp)
target_link_libraries(kernora-app-icons PRIVATE kernora-appicons)
install(TARGETS kernora-app-icons ${KDE_INSTALL_TARGETS_DEFAULT_ARGS})
