// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "agent.h"

#include <QApplication>
#include <QDir>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QStandardPaths>
#include <QUrl>

#include <BluezQt/InitManagerJob>
#include <BluezQt/Manager>
#include <BluezQt/PendingCall>

#include <KAboutData>
#include <KDBusService>
#include <KLocalizedQmlContext>
#include <KLocalizedString>

static QString interfaceFile()
{
    const QString override = qEnvironmentVariable("KERNORA_QML_BLUETOOTHAGENT");
    if (!override.isEmpty()) {
        return QDir(override).filePath(QStringLiteral("Main.qml"));
    }
    return QStandardPaths::locate(QStandardPaths::GenericDataLocation, QStringLiteral("kernora/bluetoothagent/Main.qml"));
}

int main(int argc, char **argv)
{
    if (qEnvironmentVariableIsEmpty("QT_QUICK_CONTROLS_STYLE")) {
        QQuickStyle::setStyle(QStringLiteral("org.kernora.desktop"));
    }
    QApplication app(argc, argv);
    QApplication::setQuitOnLastWindowClosed(false);
    KLocalizedString::setApplicationDomain("kernora-bluetooth-agent");

    KAboutData about(QStringLiteral("kernora-bluetooth-agent"), i18n("Bluetooth pairing"), QStringLiteral(KERNORA_APPS_VERSION));
    about.setDesktopFileName(QStringLiteral("org.kernora.bluetooth-agent"));
    about.setOrganizationDomain("kernora.invalid");
    KAboutData::setApplicationData(about);

    KDBusService service(KDBusService::Unique);

    BluezQt::Manager manager;
    PairingAgent agent;

    auto registerAgent = [&manager, &agent]() {
        if (!manager.isOperational()) {
            return;
        }
        BluezQt::PendingCall *call = manager.registerAgent(&agent);
        QObject::connect(call, &BluezQt::PendingCall::finished, &agent, [&manager, &agent](BluezQt::PendingCall *registered) {
            if (registered->error() && registered->error() != BluezQt::PendingCall::AlreadyExists) {
                qWarning("kernora-bluetooth-agent: %s", qPrintable(registered->errorText()));
                return;
            }
            manager.requestDefaultAgent(&agent);
        });
    };

    QObject::connect(&manager, &BluezQt::Manager::operationalChanged, &agent, [registerAgent](bool operational) {
        if (operational) {
            registerAgent();
        }
    });
    QObject::connect(&agent, &PairingAgent::released, &agent, registerAgent, Qt::QueuedConnection);

    BluezQt::InitManagerJob *job = manager.init();
    QObject::connect(job, &BluezQt::InitManagerJob::result, &agent, [registerAgent](BluezQt::InitManagerJob *finished) {
        if (finished->error()) {
            qWarning("kernora-bluetooth-agent: %s", qPrintable(finished->errorText()));
            return;
        }
        registerAgent();
    });
    job->start();

    QQmlApplicationEngine engine;
    KLocalization::setupLocalizedContext(&engine);
    engine.rootContext()->setContextProperty(QStringLiteral("agent"), &agent);

    const QString file = interfaceFile();
    if (file.isEmpty()) {
        qCritical("kernora-bluetooth-agent: the interface is not installed");
        return 1;
    }
    engine.load(QUrl::fromLocalFile(file));
    if (engine.rootObjects().isEmpty()) {
        return 1;
    }
    return app.exec();
}
