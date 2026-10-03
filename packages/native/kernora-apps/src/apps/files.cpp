// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "host.h"

static KLocalizedString displayName()
{
    return ki18nc("@title application name", "Files");
}

int main(int argc, char **argv)
{
    static const Kernora::Application application{"kernora-files", "org.kernora.files", "files", "org.kernora.files", false};
    return Kernora::run(argc, argv, application, displayName);
}
