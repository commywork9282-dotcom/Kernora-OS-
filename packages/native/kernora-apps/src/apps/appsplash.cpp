// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "host.h"

#include <QGuiApplication>
#include <QRegularExpression>

static KLocalizedString displayName()
{
    return ki18nc("@title application name", "Android apps");
}

static void useAppIdentity(QQmlEngine &)
{
    static const QRegularExpression package(QStringLiteral("^[A-Za-z0-9_]+(\\.[A-Za-z0-9_]+)+$"));
    const QStringList arguments = QCoreApplication::arguments().mid(1);
    for (const QString &argument : arguments) {
        if (package.match(argument).hasMatch()) {
            QGuiApplication::setDesktopFileName(QStringLiteral("waydroid.") + argument);
            return;
        }
    }
}

int main(int argc, char **argv)
{
    static const Kernora::Application application{"kernora-appsplash", "org.kernora.appsplash", "appsplash", "org.kernora.android", false,
                                                  useAppIdentity};
    return Kernora::run(argc, argv, application, displayName);
}
