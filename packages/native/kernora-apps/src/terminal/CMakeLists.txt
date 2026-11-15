# SPDX-FileCopyrightText: 2026 Kernora Developers
# SPDX-License-Identifier: GPL-2.0-or-later

find_package(qtermwidget6 2.0 REQUIRED)

remove_definitions(-DQT_NO_KEYWORDS)
get_directory_property(terminal_definitions COMPILE_DEFINITIONS)
list(REMOVE_ITEM terminal_definitions QT_NO_KEYWORDS)
set_directory_properties(PROPERTIES COMPILE_DEFINITIONS "${terminal_definitions}")

add_executable(kernora-terminal
    main.cpp
    terminalapp.cpp terminalapp.h
    terminalwindow.cpp terminalwindow.h
    windowshadow.cpp windowshadow.h)
target_link_libraries(kernora-terminal PRIVATE
    Qt6::Widgets Qt6::Qml Qt6::Quick Qt6::QuickWidgets Qt6::QuickControls2
    KF6::ConfigCore KF6::CoreAddons KF6::DBusAddons KF6::I18n KF6::I18nQml KF6::WindowSystem
    qtermwidget6)
target_compile_definitions(kernora-terminal PRIVATE
    TRANSLATION_DOMAIN="kernora-terminal"
    KERNORA_APPS_VERSION="${PROJECT_VERSION}")
install(TARGETS kernora-terminal ${KDE_INSTALL_TARGETS_DEFAULT_ARGS})
