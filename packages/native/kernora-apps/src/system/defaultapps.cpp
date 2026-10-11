// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "defaultapps.h"

#include <QMimeDatabase>
#include <QProcess>
#include <QStandardPaths>
#include <QUrl>

#include <KApplicationTrader>
#include <KConfigGroup>
#include <KLocalizedString>
#include <KService>
#include <KSharedConfig>

DefaultApps::DefaultApps(QObject *parent)
    : QObject(parent)
{
}

QVariantList DefaultApps::categories() const
{
    auto item = [](const QString &id, const QString &label, const QString &icon) {
        return QVariantMap{{QStringLiteral("id"), id}, {QStringLiteral("label"), label}, {QStringLiteral("icon"), icon}};
    };
    return {
        item(QStringLiteral("browser"), i18n("Web browser"), QStringLiteral("globe")),
        item(QStringLiteral("files"), i18n("Files"), QStringLiteral("folder")),
        item(QStringLiteral("terminal"), i18n("Terminal"), QStringLiteral("console")),
        item(QStringLiteral("text"), i18n("Text"), QStringLiteral("document-edit")),
        item(QStringLiteral("images"), i18n("Pictures"), QStringLiteral("image-x-generic")),
        item(QStringLiteral("video"), i18n("Video"), QStringLiteral("video-x-generic")),
        item(QStringLiteral("music"), i18n("Music"), QStringLiteral("audio-x-generic")),
        item(QStringLiteral("pdf"), i18n("Documents"), QStringLiteral("text-x-generic")),
        item(QStringLiteral("email"), i18n("Email"), QStringLiteral("mail")),
    };
}

QStringList DefaultApps::mimeTypes(const QString &category)
{
    if (category == QLatin1String("browser")) {
        return {QStringLiteral("x-scheme-handler/http"), QStringLiteral("x-scheme-handler/https"),
                QStringLiteral("text/html"), QStringLiteral("application/xhtml+xml")};
    }
    if (category == QLatin1String("files")) {
        return {QStringLiteral("inode/directory")};
    }
    if (category == QLatin1String("text")) {
        return {QStringLiteral("text/plain"), QStringLiteral("text/markdown"), QStringLiteral("text/x-log"),
                QStringLiteral("application/x-shellscript"), QStringLiteral("text/x-python"),
                QStringLiteral("application/json"), QStringLiteral("application/xml")};
    }
    if (category == QLatin1String("images")) {
        return {QStringLiteral("image/png"), QStringLiteral("image/jpeg"), QStringLiteral("image/gif"),
                QStringLiteral("image/webp"), QStringLiteral("image/bmp"), QStringLiteral("image/svg+xml"),
                QStringLiteral("image/tiff"), QStringLiteral("image/avif")};
    }
    if (category == QLatin1String("video")) {
        return {QStringLiteral("video/mp4"), QStringLiteral("video/x-matroska"), QStringLiteral("video/webm"),
                QStringLiteral("video/mpeg"), QStringLiteral("video/quicktime"), QStringLiteral("video/x-msvideo"),
                QStringLiteral("video/ogg")};
    }
    if (category == QLatin1String("music")) {
        return {QStringLiteral("audio/mpeg"), QStringLiteral("audio/flac"), QStringLiteral("audio/ogg"),
                QStringLiteral("audio/x-wav"), QStringLiteral("audio/mp4"), QStringLiteral("audio/x-vorbis+ogg"),
                QStringLiteral("audio/opus")};
    }
    if (category == QLatin1String("pdf")) {
        return {QStringLiteral("application/pdf")};
    }
    if (category == QLatin1String("email")) {
        return {QStringLiteral("x-scheme-handler/mailto")};
    }
    return {};
}

static QVariantMap describe(const KService::Ptr &service)
{
    if (!service) {
        return {};
    }
    return {{QStringLiteral("storageId"), service->storageId()},
            {QStringLiteral("name"), service->name()},
            {QStringLiteral("icon"), service->icon()}};
}

QVariantList DefaultApps::candidates(const QString &category) const
{
    QVariantList list;
    QStringList seen;
    if (category == QLatin1String("terminal")) {
        const auto services = KApplicationTrader::query([](const KService::Ptr &service) {
            return service->categories().contains(QLatin1String("TerminalEmulator"));
        });
        for (const auto &service : services) {
            list.append(describe(service));
        }
        return list;
    }
    const QStringList types = mimeTypes(category);
    for (const QString &type : types) {
        for (const auto &service : KApplicationTrader::queryByMimeType(type)) {
            if (!seen.contains(service->storageId())) {
                seen.append(service->storageId());
                list.append(describe(service));
            }
        }
    }
    return list;
}

QString DefaultApps::current(const QString &category) const
{
    if (category == QLatin1String("terminal")) {
        const KConfigGroup general(KSharedConfig::openConfig(), QStringLiteral("General"));
        const QString service = general.readEntry("TerminalService", QString());
        if (!service.isEmpty()) {
            return service;
        }
        const auto candidates = this->candidates(category);
        return candidates.isEmpty() ? QString() : candidates.first().toMap().value(QStringLiteral("storageId")).toString();
    }
    const QStringList types = mimeTypes(category);
    if (types.isEmpty()) {
        return QString();
    }
    const KConfig mimeApps(QStringLiteral("mimeapps.list"), KConfig::NoGlobals, QStandardPaths::GenericConfigLocation);
    const KConfigGroup defaults(&mimeApps, QStringLiteral("Default Applications"));
    for (const QString &storageId : defaults.readXdgListEntry(types.first())) {
        if (KService::serviceByStorageId(storageId)) {
            return storageId;
        }
    }
    const auto service = KApplicationTrader::preferredService(types.first());
    return service ? service->storageId() : QString();
}

QVariantMap DefaultApps::currentApplication(const QString &category) const
{
    return describe(KService::serviceByStorageId(current(category)));
}

void DefaultApps::setDefault(const QString &category, const QString &storageId)
{
    const KService::Ptr service = KService::serviceByStorageId(storageId);
    if (!service) {
        return;
    }
    if (category == QLatin1String("terminal")) {
        KConfigGroup general(KSharedConfig::openConfig(), QStringLiteral("General"));
        general.writeEntry("TerminalApplication", service->exec().section(QLatin1Char(' '), 0, 0), KConfig::Notify);
        general.writeEntry("TerminalService", storageId, KConfig::Notify);
        general.sync();
        Q_EMIT changed(category);
        return;
    }
    auto mimeApps = KSharedConfig::openConfig(QStringLiteral("mimeapps.list"), KConfig::NoGlobals,
                                              QStandardPaths::GenericConfigLocation);
    KConfigGroup defaults(mimeApps, QStringLiteral("Default Applications"));
    KConfigGroup added(mimeApps, QStringLiteral("Added Associations"));
    for (const QString &type : mimeTypes(category)) {
        defaults.writeXdgListEntry(type, {storageId});
        QStringList associations = added.readXdgListEntry(type);
        associations.removeAll(storageId);
        associations.prepend(storageId);
        added.writeXdgListEntry(type, associations);
    }
    mimeApps->sync();
    QProcess::startDetached(QStringLiteral("kbuildsycoca6"), {});
    Q_EMIT changed(category);
}

QVariantList DefaultApps::applicationsFor(const QUrl &url) const
{
    const QString type = QMimeDatabase().mimeTypeForUrl(url).name();
    QVariantList list;
    for (const auto &service : KApplicationTrader::queryByMimeType(type)) {
        list.append(describe(service));
    }
    return list;
}
