# SPDX-FileCopyrightText: 2026 Kernora Developers
# SPDX-License-Identifier: GPL-2.0-or-later

ecm_add_qml_module(kernorashell URI "org.kernora.shell" VERSION 1.0 GENERATE_PLUGIN_SOURCE)

target_sources(kernorashell PRIVATE
    appletsettings.cpp appletsettings.h
)

target_link_libraries(kernorashell PRIVATE
    Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick
    Plasma::Plasma Plasma::PlasmaQuick
)

ecm_finalize_qml_module(kernorashell DESTINATION ${KDE_INSTALL_QMLDIR})
