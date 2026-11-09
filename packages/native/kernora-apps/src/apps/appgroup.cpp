// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "host.h"

static KLocalizedString displayName()
{
    return ki18nc("@title application name", "App Group");
}

int main(int argc, char **argv)
{
    static const Kernora::Application application{"kernora-appgroup", "org.kernora.appgroup", "appgroup", "view-app-grid", false};
    return Kernora::run(argc, argv, application, displayName);
}
