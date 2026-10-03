// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "process.h"

#include <QJSEngine>
#include <QProcess>
#include <QStandardPaths>

#include <KIO/ApplicationLauncherJob>
#include <KIO/OpenUrlJob>
#include <KPluginMetaData>
#include <KService>

Process::Process(QObject *parent)
    : QObject(parent)
{
}

void Process::run(const QString &program, const QStringList &arguments, const QJSValue &callback, const QString &input)
{
    auto *process = new QProcess(this);
    process->setProgram(program);
    process->setArguments(arguments);
    connect(process, &QProcess::finished, this, [this, process, callback](int exitCode, QProcess::ExitStatus status) {
        if (callback.isCallable() && qjsEngine(this)) {
            QJSValue function = callback;
            const int code = status == QProcess::NormalExit ? exitCode : -1;
            function.call({QJSValue(code), QJSValue(QString::fromUtf8(process->readAllStandardOutput())),
                           QJSValue(QString::fromUtf8(process->readAllStandardError()))});
        }
        process->deleteLater();
    });
    connect(process, &QProcess::errorOccurred, this, [this, process, callback](QProcess::ProcessError error) {
        if (error != QProcess::FailedToStart) {
            return;
        }
        if (callback.isCallable() && qjsEngine(this)) {
            QJSValue function = callback;
            function.call({QJSValue(-1), QJSValue(QString()), QJSValue(process->errorString())});
        }
        process->deleteLater();
    });
    process->start();
    if (!input.isEmpty()) {
        process->write(input.toUtf8());
    }
    process->closeWriteChannel();
}

bool Process::startDetached(const QString &program, const QStringList &arguments)
{
    return QProcess::startDetached(program, arguments);
}

void Process::openUrl(const QUrl &url)
{
    auto *job = new KIO::OpenUrlJob(url);
    job->start();
}

QVariantMap Process::application(const QString &desktopEntry) const
{
    QString name = desktopEntry;
    if (name.endsWith(QLatin1String(".desktop"))) {
        name.chop(8);
    }
    KService::Ptr service = KService::serviceByDesktopName(name);
    if (!service) {
        service = KService::serviceByStorageId(desktopEntry);
    }
    if (!service) {
        return {};
    }
    return {{QStringLiteral("name"), service->name()},
            {QStringLiteral("icon"), service->icon()},
            {QStringLiteral("storageId"), service->storageId()},
            {QStringLiteral("comment"), service->comment()}};
}

bool Process::launchApplication(const QString &storageId, const QList<QUrl> &urls)
{
    KService::Ptr service = KService::serviceByStorageId(storageId);
    if (!service) {
        return false;
    }
    auto *job = new KIO::ApplicationLauncherJob(service);
    job->setUrls(urls);
    job->start();
    return true;
}

void Process::openModule(const QString &module)
{
    QProcess::startDetached(QStringLiteral("kcmshell6"), {module});
}

QString Process::findExecutable(const QString &name) const
{
    return QStandardPaths::findExecutable(name);
}

QString Process::environment(const QString &name) const
{
    return qEnvironmentVariable(name.toUtf8().constData());
}

QVariantList Process::settingsModules() const
{
    QVariantList list;
    QStringList seen;
    for (const QString &directory : {QStringLiteral("plasma/kcms/systemsettings"), QStringLiteral("plasma/kcms/systemsettings_qwidgets")}) {
        for (const KPluginMetaData &plugin : KPluginMetaData::findPlugins(directory)) {
            if (seen.contains(plugin.pluginId()) || plugin.name().isEmpty()) {
                continue;
            }
            seen.append(plugin.pluginId());
            list.append(QVariantMap{{QStringLiteral("id"), plugin.pluginId()},
                                    {QStringLiteral("name"), plugin.name()},
                                    {QStringLiteral("description"), plugin.description()},
                                    {QStringLiteral("icon"), plugin.iconName()}});
        }
    }
    std::sort(list.begin(), list.end(), [](const QVariant &a, const QVariant &b) {
        return a.toMap().value(QStringLiteral("name")).toString().localeAwareCompare(b.toMap().value(QStringLiteral("name")).toString()) < 0;
    });
    return list;
}
