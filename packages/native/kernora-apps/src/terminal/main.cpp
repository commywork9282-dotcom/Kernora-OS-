// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "terminalapp.h"

#include <QApplication>
#include <QDir>
#include <QFileInfo>
#include <QIcon>
#include <QQuickStyle>

#include <KAboutData>
#include <KDBusService>
#include <KLocalizedString>

namespace
{
struct Request {
    QString directory;
    QStringList command;
};

Request parse(const QStringList &arguments, const QString &workingDirectory)
{
    Request request;
    for (qsizetype i = 1; i < arguments.size(); ++i) {
        const QString &argument = arguments.at(i);
        if (argument == QLatin1String("-e") || argument == QLatin1String("--command") || argument == QLatin1String("-x")) {
            request.command = arguments.mid(i + 1);
            if (request.command.size() == 1 && request.command.first().contains(QLatin1Char(' '))) {
                request.command = {QStringLiteral("/bin/sh"), QStringLiteral("-c"), request.command.first()};
            }
            break;
        }
        if ((argument == QLatin1String("--workdir") || argument == QLatin1String("--working-directory")) && i + 1 < arguments.size()) {
            request.directory = arguments.at(++i);
            continue;
        }
        for (const QLatin1String prefix : {QLatin1String("--workdir="), QLatin1String("--working-directory=")}) {
            if (argument.startsWith(prefix)) {
                request.directory = argument.mid(prefix.size());
            }
        }
    }
    if (request.directory.isEmpty()) {
        request.directory = workingDirectory;
    } else if (QFileInfo(request.directory).isRelative()) {
        request.directory = QDir(workingDirectory).absoluteFilePath(request.directory);
    }
    return request;
}
}

int main(int argc, char **argv)
{
    if (qEnvironmentVariableIsEmpty("QT_QUICK_CONTROLS_STYLE")) {
        QQuickStyle::setStyle(QStringLiteral("org.kernora.desktop"));
    }
    QApplication app(argc, argv);
    KLocalizedString::setApplicationDomain("kernora-terminal");

    KAboutData about(QStringLiteral("kernora-terminal"), i18nc("@title application name", "Terminal"), QStringLiteral(KERNORA_APPS_VERSION), QString(),
                     KAboutLicense::GPL_V2, i18nc("@info:credit", "© 2026 Kernora OS"));
    about.setDesktopFileName(QStringLiteral("org.kernora.terminal"));
    about.setOrganizationDomain("kernora.invalid");
    KAboutData::setApplicationData(about);
    QApplication::setWindowIcon(QIcon::fromTheme(QStringLiteral("org.kernora.terminal")));

    const QStringList arguments = QCoreApplication::arguments();
    if (arguments.contains(QLatin1String("--version")) || arguments.contains(QLatin1String("-v"))) {
        printf("kernora-terminal %s\n", KERNORA_APPS_VERSION);
        return 0;
    }

    KDBusService service(KDBusService::Unique);
    TerminalApp terminal;
    QObject::connect(&service, &KDBusService::activateRequested, &terminal, [&terminal](const QStringList &received, const QString &workingDirectory) {
        const Request request = parse(received, workingDirectory);
        terminal.newWindow(request.directory, request.command);
    });

    const Request request = parse(arguments, QDir::currentPath());
    terminal.newWindow(request.directory, request.command);
    return app.exec();
}
