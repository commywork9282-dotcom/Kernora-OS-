# SPDX-FileCopyrightText: 2026 Kernora Developers
# SPDX-License-Identifier: GPL-2.0-or-later

add_executable(kernora-settings-runner main.cpp)
target_link_libraries(kernora-settings-runner PRIVATE Qt6::Gui Qt6::DBus Qt6::Qml KF6::I18n KF6::I18nQml)
target_compile_definitions(kernora-settings-runner PRIVATE TRANSLATION_DOMAIN="kernora-settings")
install(TARGETS kernora-settings-runner DESTINATION ${KDE_INSTALL_LIBEXECDIR})

configure_file(org.kernora.settings.runner.service.in ${CMAKE_CURRENT_BINARY_DIR}/org.kernora.settings.runner.service @ONLY)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/org.kernora.settings.runner.service DESTINATION ${KDE_INSTALL_DBUSSERVICEDIR})
install(FILES org.kernora.settings.desktop DESTINATION ${KDE_INSTALL_DATADIR}/krunner/dbusplugins)
