# SPDX-FileCopyrightText: 2026 Kernora Developers
# SPDX-License-Identifier: GPL-2.0-or-later

add_library(kernorahost STATIC host.cpp host.h)
target_link_libraries(kernorahost PUBLIC
    Qt6::Widgets Qt6::Qml Qt6::Quick Qt6::QuickControls2 Qt6::Network
    KF6::CoreAddons KF6::DBusAddons KF6::I18n KF6::I18nQml)
target_compile_definitions(kernorahost PUBLIC KERNORA_APPS_VERSION="${PROJECT_VERSION}")

foreach(app settings files welcome editor photos player calculator screenshot store share taskmanager apkinstaller appsplash)
    add_executable(kernora-${app} ${app}.cpp)
    target_link_libraries(kernora-${app} PRIVATE kernorahost)
    target_compile_definitions(kernora-${app} PRIVATE TRANSLATION_DOMAIN="kernora-${app}")
    install(TARGETS kernora-${app} ${KDE_INSTALL_TARGETS_DEFAULT_ARGS})
endforeach()
