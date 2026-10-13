// SPDX-FileCopyrightText: 2026 Lumo contributors
// SPDX-License-Identifier: GPL-2.0-or-later

#include "host.h"

static KLocalizedString displayName()
{
    return ki18nc("@title application name", "Task Manager");
}

int main(int argc, char **argv)
{
    static const Kernora::Application application{"kernora-tasks", "org.kernora.tasks", "tasks", "org.kernora.tasks", true};
    return Kernora::run(argc, argv, application, displayName);
}
