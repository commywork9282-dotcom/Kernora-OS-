// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "host.h"

static KLocalizedString displayName()
{
    return ki18nc("@title application name", "Android App Question");
}

int main(int argc, char **argv)
{
    static const Kernora::Application application{"kernora-androiddialog", "org.kernora.androiddialog", "androiddialog", "kernora-android", false};
    return Kernora::run(argc, argv, application, displayName);
}
