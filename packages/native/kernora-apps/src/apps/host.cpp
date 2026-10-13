// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "host.h"

#include <QApplication>
#include <QCommandLineParser>
#include <QDir>
#include <QFileInfo>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QStandardPaths>
#include <QUrl>

#include <KAboutData>
#include <KDBusService>
#include <KLocalizedQmlContext>

namespace Kernora
{
static QString interfaceFile(const Application &application)
{
    const QByteArray variable = "KERNORA_QML_" + QByteArray(application.folder).toUpper();
    const QString override = qEnvironmentVariable(variable.constData());
    if (!override.isEmpty()) {
        return QDir(override).filePath(QStringLiteral("Main.qml"));
    }
    return QStandardPaths::locate(QStandardPaths::GenericDataLocation,
                                  QStringLiteral("kernora/%1/Main.qml").arg(QString::fromLatin1(application.folder)));
}

static QStringList normalised(const QStringList &arguments, const QString &workingDirectory)
{
    QStringList result;
    for (const QString &argument : arguments) {
        if (argument.startsWith(QLatin1Char('-')) || argument.contains(QLatin1String("://"))) {
            result.append(argument);
            continue;
        }
        const QFileInfo file(QDir(workingDirectory).absoluteFilePath(argument));
        result.append(file.exists() ? QUrl::fromLocalFile(file.absoluteFilePath()).toString() : argument);
    }
    return result;
}

int run(int &argc, char **argv, const Application &application, KLocalizedString (*displayName)())
{
    if (qEnvironmentVariableIsEmpty("QT_QUICK_CONTROLS_STYLE")) {
        QQuickStyle::setStyle(QStringLiteral("org.kernora.desktop"));
    }
    QApplication app(argc, argv);
    KLocalizedString::setApplicationDomain(application.component);

    KAboutData about(QString::fromLatin1(application.component), displayName().toString(),
                     QStringLiteral(KERNORA_APPS_VERSION), QString(), KAboutLicense::GPL_V2,
                     i18nc("@info:credit", "© 2026 Lumo"));
    about.setDesktopFileName(QString::fromLatin1(application.desktopFileName));
    about.setOrganizationDomain("kernora.invalid");
    KAboutData::setApplicationData(about);
    QApplication::setWindowIcon(QIcon::fromTheme(QString::fromLatin1(application.icon)));

    QCommandLineParser parser;
    about.setupCommandLine(&parser);
    parser.addPositionalArgument(QStringLiteral("arguments"), i18n("Files or pages to open."), QStringLiteral("[arguments…]"));
    QCommandLineOption moduleArguments(QStringLiteral("args"), QString(), QStringLiteral("arguments"));
    moduleArguments.setFlags(QCommandLineOption::HiddenFromHelp);
    parser.addOption(moduleArguments);
    QCommandLineOption firstRun(QStringLiteral("first-run"));
    firstRun.setFlags(QCommandLineOption::HiddenFromHelp);
    parser.addOption(firstRun);
    QCommandLineOption whatsNew(QStringLiteral("whats-new"));
    whatsNew.setFlags(QCommandLineOption::HiddenFromHelp);
    parser.addOption(whatsNew);
    QCommandLineOption kernelPanic(QStringLiteral("kernel-panic"));
    kernelPanic.setFlags(QCommandLineOption::HiddenFromHelp);
    parser.addOption(kernelPanic);
    parser.process(app);
    about.processCommandLine(&parser);
    QStringList arguments = normalised(parser.positionalArguments(), QDir::currentPath());
    if (parser.isSet(firstRun)) {
        arguments.prepend(QStringLiteral("--first-run"));
    }
    if (parser.isSet(whatsNew)) {
        arguments.prepend(QStringLiteral("--whats-new"));
    }
    if (parser.isSet(kernelPanic)) {
        arguments.prepend(QStringLiteral("--kernel-panic"));
    }

    std::unique_ptr<KDBusService> service;
    if (application.unique) {
        service = std::make_unique<KDBusService>(KDBusService::Unique);
    }

    QQmlApplicationEngine engine;
    KLocalization::setupLocalizedContext(&engine);
    if (application.setup) {
        application.setup(engine);
    }
    engine.rootContext()->setContextProperty(QStringLiteral("startArguments"), arguments);

    const QString file = interfaceFile(application);
    if (file.isEmpty()) {
        qCritical("%s: the interface is not installed", application.component);
        return 1;
    }
    engine.load(QUrl::fromLocalFile(file));
    if (engine.rootObjects().isEmpty()) {
        return 1;
    }

    if (service) {
        QObject::connect(service.get(), &KDBusService::activateRequested, &engine,
                         [&engine](const QStringList &received, const QString &workingDirectory) {
                             QObject *root = engine.rootObjects().value(0);
                             if (!root) {
                                 return;
                             }
                             const QStringList forwarded = normalised(received.mid(1), workingDirectory);
                             QMetaObject::invokeMethod(root, "handleArguments", Q_ARG(QVariant, QVariant(forwarded)));
                             if (auto *window = qobject_cast<QQuickWindow *>(root)) {
                                 window->show();
                                 window->raise();
                                 window->requestActivate();
                             }
                         });
    }
    return app.exec();
}

}
