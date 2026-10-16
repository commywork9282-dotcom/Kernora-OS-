# SPDX-FileCopyrightText: 2026 Kernora Developers
# SPDX-License-Identifier: GPL-2.0-or-later

add_executable(kernora-update-notifier main.cpp greetersync.cpp greetersync.h)
target_link_libraries(kernora-update-notifier PRIVATE
    Qt6::Gui Qt6::DBus Qt6::Network
    KF6::ConfigCore KF6::CoreAddons KF6::DBusAddons KF6::I18n KF6::Notifications
    PK::packagekitqt6)
target_compile_definitions(kernora-update-notifier PRIVATE
    TRANSLATION_DOMAIN="kernora-update-notifier"
    KERNORA_APPS_VERSION="${PROJECT_VERSION}")
install(TARGETS kernora-update-notifier ${KDE_INSTALL_TARGETS_DEFAULT_ARGS})
