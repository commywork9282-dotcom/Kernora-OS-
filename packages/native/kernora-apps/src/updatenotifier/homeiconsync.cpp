// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "homeiconsync.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSaveFile>
#include <QSet>
#include <QStandardPaths>

#include <KConfig>
#include <KConfigGroup>
#include <KService>
#include <KSycoca>

namespace
{
constexpr int SettleDelay = 2000;

QString stateFile()
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericStateLocation) + QStringLiteral("/kernora/home-apps");
}

QSet<QString> installedApps()
{
    QSet<QString> apps;
    const KService::List services = KService::allServices();
    for (const KService::Ptr &service : services) {
        if (!service->isApplication() || service->noDisplay() || !service->showInCurrentDesktop() || !service->showOnCurrentPlatform()
            || service->exec().isEmpty()) {
            continue;
        }
        const QString id = service->storageId();
        if (id.isEmpty() || id.startsWith(QLatin1String("org.kernora."))) {
            continue;
        }
        apps.insert(id);
    }
    return apps;
}

QSet<QString> readKnown(bool *exists)
{
    QFile file(stateFile());
    *exists = file.exists();
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return {};
    }
    const QStringList lines = QString::fromUtf8(file.readAll()).split(QLatin1Char('\n'), Qt::SkipEmptyParts);
    return QSet<QString>(lines.cbegin(), lines.cend());
}

void writeKnown(const QSet<QString> &apps)
{
    QDir().mkpath(QFileInfo(stateFile()).absolutePath());
    QStringList list(apps.cbegin(), apps.cend());
    list.sort();
    QSaveFile file(stateFile());
    if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        file.write(list.join(QLatin1Char('\n')).toUtf8() + '\n');
        file.commit();
    }
}

QString homeFolder()
{
    const QString desktop = QStandardPaths::writableLocation(QStandardPaths::DesktopLocation);
    if (desktop.isEmpty() || QDir(desktop) == QDir(QDir::homePath())) {
        return {};
    }
    QDir().mkpath(desktop);
    return desktop;
}

QString sourcePath(const KService::Ptr &service)
{
    const QString path = service->entryPath();
    if (QFileInfo(path).isAbsolute()) {
        return path;
    }
    return QStandardPaths::locate(QStandardPaths::ApplicationsLocation, service->storageId());
}

void addToHome(const KService::Ptr &service, const QString &folder)
{
    const QString target = folder + QLatin1Char('/') + service->storageId();
    if (QFileInfo::exists(target)) {
        return;
    }
    QFile source(sourcePath(service));
    if (!source.open(QIODevice::ReadOnly)) {
        return;
    }
    QSaveFile file(target);
    if (!file.open(QIODevice::WriteOnly)) {
        return;
    }
    file.write(source.readAll());
    if (!file.commit()) {
        return;
    }
    QFile::setPermissions(target, QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner | QFileDevice::ReadGroup
                              | QFileDevice::ExeGroup | QFileDevice::ReadOther | QFileDevice::ExeOther);
}
}

HomeIconSync::HomeIconSync()
{
    m_timer.setSingleShot(true);
    connect(&m_timer, &QTimer::timeout, this, &HomeIconSync::sync);
    connect(KSycoca::self(), &KSycoca::databaseChanged, this, [this]() {
        m_timer.start(SettleDelay);
    });
    m_timer.start(SettleDelay * 2);
}

void HomeIconSync::sync()
{
    const QSet<QString> current = installedApps();
    if (current.isEmpty()) {
        return;
    }
    bool exists = false;
    const QSet<QString> known = readKnown(&exists);
    if (exists) {
        KConfig kernora(QStringLiteral("kernorarc"), KConfig::SimpleConfig);
        const bool add = kernora.group(QStringLiteral("Home")).readEntry("addAppIcons", true);
        const QString folder = add ? homeFolder() : QString();
        for (const QString &id : current) {
            if (folder.isEmpty()) {
                break;
            }
            if (known.contains(id)) {
                continue;
            }
            if (const KService::Ptr service = KService::serviceByStorageId(id)) {
                addToHome(service, folder);
            }
        }
    }
    if (!exists || current != known) {
        writeKnown(current);
    }
}
