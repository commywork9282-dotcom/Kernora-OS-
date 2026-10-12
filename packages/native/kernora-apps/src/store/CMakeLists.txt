# SPDX-FileCopyrightText: 2026 Kernora Developers
# SPDX-License-Identifier: GPL-2.0-or-later

ecm_add_qml_module(kernorastore URI "org.kernora.store" VERSION 1.0 GENERATE_PLUGIN_SOURCE)

target_sources(kernorastore PRIVATE
    appmodel.cpp appmodel.h
    debianbackend.cpp debianbackend.h
    flatpakbackend.cpp flatpakbackend.h
    store.cpp store.h
)

target_link_libraries(kernorastore PRIVATE
    Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::Network
    KF6::CoreAddons KF6::I18n KF6::KIOGui KF6::Notifications KF6::Service
    AppStreamQt
    PK::packagekitqt6
    PkgConfig::FLATPAK
)

ecm_finalize_qml_module(kernorastore DESTINATION ${KDE_INSTALL_QMLDIR})
target_compile_definitions(kernorastore PRIVATE TRANSLATION_DOMAIN="kernora-store")
