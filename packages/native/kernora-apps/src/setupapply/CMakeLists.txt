# SPDX-FileCopyrightText: 2026 Kernora Developers
# SPDX-License-Identifier: GPL-2.0-or-later

add_executable(kernora-setup-apply main.cpp)
target_link_libraries(kernora-setup-apply PRIVATE Qt6::Gui Qt6::Qml Qt6::DBus KF6::ConfigCore)
install(TARGETS kernora-setup-apply DESTINATION ${KDE_INSTALL_LIBEXECDIR})
