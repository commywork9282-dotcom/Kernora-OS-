# SPDX-FileCopyrightText: 2026 Kernora Developers
# SPDX-License-Identifier: GPL-2.0-or-later

cmake_minimum_required(VERSION 3.25)
project(kernora-apps VERSION 1.1.65 LANGUAGES CXX)

set(QT_MIN_VERSION 6.8)
set(KF_MIN_VERSION 6.13)

find_package(ECM ${KF_MIN_VERSION} REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(ECMQmlModule)
include(FeatureSummary)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 ${QT_MIN_VERSION} REQUIRED COMPONENTS
    Core Gui Qml Quick QuickControls2 Widgets DBus Network Svg)
find_package(KF6 ${KF_MIN_VERSION} REQUIRED COMPONENTS
    Archive Config CoreAddons DBusAddons I18n KIO Notifications Service WindowSystem)
find_package(KF6Screen REQUIRED)
find_package(PackageKitQt6 REQUIRED)
find_package(Plasma REQUIRED)
find_package(PlasmaQuick REQUIRED)
find_package(PkgConfig REQUIRED)
pkg_check_modules(LIBCRYPT REQUIRED IMPORTED_TARGET libcrypt)
pkg_check_modules(FLATPAK REQUIRED IMPORTED_TARGET flatpak)
find_package(AppStreamQt 1.0 REQUIRED)

add_subdirectory(src/system)
add_subdirectory(src/shell)
add_subdirectory(src/store)
add_subdirectory(src/apps)
add_subdirectory(src/filechooser)
add_subdirectory(src/updatenotifier)

set(KERNORA_APPS settings files welcome editor photos player calculator screenshot store share taskmanager apkinstaller)
foreach(app ${KERNORA_APPS})
    install(DIRECTORY apps/${app}/qml/ DESTINATION ${KDE_INSTALL_DATADIR}/kernora/${app})
    install(FILES apps/${app}/org.kernora.${app}.desktop DESTINATION ${KDE_INSTALL_APPDIR})
endforeach()

install(DIRECTORY apps/filechooser/qml/ DESTINATION ${KDE_INSTALL_DATADIR}/kernora/filechooser)
install(FILES apps/taskmanager/org.kernora.taskmanager.desktop DESTINATION ${KDE_INSTALL_DATADIR}/kglobalaccel)

install(FILES apps/welcome/org.kernora.welcome-autostart.desktop
        DESTINATION ${KDE_INSTALL_AUTOSTARTDIR} RENAME org.kernora.welcome.desktop)
install(PROGRAMS data/systemsettings DESTINATION ${KDE_INSTALL_BINDIR})
install(FILES data/copyright/librewolf DESTINATION ${KDE_INSTALL_DATADIR}/kernora/copyright)
install(FILES data/knotifications/kernora-screenshot.notifyrc data/knotifications/kernora-updates.notifyrc data/knotifications/kernora-store.notifyrc
        DESTINATION ${KDE_INSTALL_KNOTIFYRCDIR})
install(FILES data/autostart/org.kernora.update-notifier.desktop DESTINATION ${KDE_INSTALL_AUTOSTARTDIR})
install(FILES data/whatsnew.json DESTINATION ${KDE_INSTALL_DATADIR}/kernora)
install(FILES data/store/featured.json DESTINATION ${KDE_INSTALL_DATADIR}/kernora/store)
install(FILES data/store/flathub.flatpakrepo DESTINATION ${KDE_INSTALL_DATADIR}/flatpak/remotes.d)
install(FILES data/store/60kernora-store DESTINATION ${KDE_INSTALL_SYSCONFDIR}/apt/apt.conf.d)

ki18n_install(po)

feature_summary(WHAT ALL FATAL_ON_MISSING_REQUIRED_PACKAGES)
