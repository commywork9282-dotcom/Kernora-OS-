// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "autostart.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>

#include <KApplicationTrader>
#include <KConfigGroup>
#include <KDesktopFile>
#include <KService>

#include <algorithm>

static QString userDirectory()
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + QStringLiteral("/autostart");
}

Autostart::Autostart(QObject *parent)
    : QObject(parent)
{
}

static bool shownInKde(const KConfigGroup &group)
{
    const QStringList only = group.readXdgListEntry("OnlyShowIn");
    const QStringList not_ = group.readXdgListEntry("NotShowIn");
    if (!only.isEmpty() && !only.contains(QLatin1String("KDE"))) {
        return false;
    }
    return !not_.contains(QLatin1String("KDE"));
}

QVariantList Autostart::entries() const
{
    QMap<QString, QVariantMap> byId;
    QStringList directories = QStandardPaths::locateAll(QStandardPaths::GenericConfigLocation, QStringLiteral("autostart"),
                                                        QStandardPaths::LocateDirectory);
    std::reverse(directories.begin(), directories.end());
    for (const QString &directory : std::as_const(directories)) {
        const bool user = directory == userDirectory();
        const auto files = QDir(directory).entryList({QStringLiteral("*.desktop")}, QDir::Files);
        for (const QString &name : files) {
            KDesktopFile file(directory + QLatin1Char('/') + name);
            const KConfigGroup group = file.desktopGroup();
            if (!user && (!shownInKde(group) || group.readEntry("NoDisplay", false))) {
                byId.remove(name);
                continue;
            }
            if (group.readEntry("X-KDE-autostart-phase", QString()) == QLatin1String("0")
                || group.readEntry("X-GNOME-Autostart-Phase", QString()) == QLatin1String("Initialization")) {
                continue;
            }
            QVariantMap entry{{QStringLiteral("id"), name},
                              {QStringLiteral("name"), file.readName()},
                              {QStringLiteral("icon"), file.readIcon()},
                              {QStringLiteral("comment"), file.readComment()},
                              {QStringLiteral("enabled"), !group.readEntry("Hidden", false)},
                              {QStringLiteral("user"), user && !byId.contains(name)}};
            if (user && byId.contains(name)) {
                QVariantMap existing = byId.value(name);
                existing.insert(QStringLiteral("enabled"), !group.readEntry("Hidden", false));
                byId.insert(name, existing);
            } else if (!file.readName().isEmpty()) {
                byId.insert(name, entry);
            }
        }
    }
    QVariantList list;
    for (const auto &entry : std::as_const(byId)) {
        list.append(entry);
    }
    std::sort(list.begin(), list.end(), [](const QVariant &a, const QVariant &b) {
        return a.toMap().value(QStringLiteral("name")).toString().localeAwareCompare(b.toMap().value(QStringLiteral("name")).toString()) < 0;
    });
    return list;
}

void Autostart::setEnabled(const QString &id, bool enabled)
{
    QDir().mkpath(userDirectory());
    const QString target = userDirectory() + QLatin1Char('/') + id;
    if (!QFile::exists(target)) {
        const QString source = QStandardPaths::locate(QStandardPaths::GenericConfigLocation, QStringLiteral("autostart/") + id);
        if (source.isEmpty() || !QFile::copy(source, target)) {
            return;
        }
        QFile::setPermissions(target, QFile::ReadOwner | QFile::WriteOwner | QFile::ReadGroup | QFile::ReadOther);
    }
    KDesktopFile file(target);
    KConfigGroup group = file.desktopGroup();
    group.writeEntry("Hidden", !enabled);
    file.sync();
    Q_EMIT changed();
}

void Autostart::add(const QString &storageId)
{
    const KService::Ptr service = KService::serviceByStorageId(storageId);
    if (!service) {
        return;
    }
    QDir().mkpath(userDirectory());
    const QString target = userDirectory() + QLatin1Char('/') + QFileInfo(service->entryPath()).fileName();
    QFile::remove(target);
    QFile::copy(service->entryPath(), target);
    QFile::setPermissions(target, QFile::ReadOwner | QFile::WriteOwner | QFile::ReadGroup | QFile::ReadOther);
    Q_EMIT changed();
}

void Autostart::remove(const QString &id)
{
    const QString target = userDirectory() + QLatin1Char('/') + id;
    const QString system = QStandardPaths::locateAll(QStandardPaths::GenericConfigLocation, QStringLiteral("autostart/") + id).value(1);
    if (!system.isEmpty()) {
        setEnabled(id, false);
        return;
    }
    QFile::remove(target);
    Q_EMIT changed();
}

QVariantList Autostart::applications() const
{
    QVariantList list;
    const auto services = KApplicationTrader::query([](const KService::Ptr &service) {
        return !service->noDisplay() && !service->exec().isEmpty();
    });
    for (const auto &service : services) {
        list.append(QVariantMap{{QStringLiteral("storageId"), service->storageId()},
                                {QStringLiteral("name"), service->name()},
                                {QStringLiteral("icon"), service->icon()}});
    }
    std::sort(list.begin(), list.end(), [](const QVariant &a, const QVariant &b) {
        return a.toMap().value(QStringLiteral("name")).toString().localeAwareCompare(b.toMap().value(QStringLiteral("name")).toString()) < 0;
    });
    return list;
}
