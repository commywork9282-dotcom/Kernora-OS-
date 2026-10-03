// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <KLocalizedString>

namespace Kernora
{
struct Application {
    const char *component;
    const char *desktopFileName;
    const char *folder;
    const char *icon;
    bool unique;
};

int run(int &argc, char **argv, const Application &application, KLocalizedString (*displayName)());
}
