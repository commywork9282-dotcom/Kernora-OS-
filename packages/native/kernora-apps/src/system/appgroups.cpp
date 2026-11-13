// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "appgroups.h"

#include <KConfig>
#include <KConfigGroup>
#include <KDesktopFile>
#include <KIO/ApplicationLauncherJob>
#include <KLocalizedString>
#include <KService>

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QIcon>
#include <QImage>
#include <QPainter>
#include <QStandardPaths>
#include <QUrl>
#include <QUuid>

namespace
{
const QString GroupKey = QStringLiteral("X-Kernora-AppGroup");
const QString OrderKey = QStringLiteral("X-Kernora-AppGroupOrder");
const QString EntryGroup = QStringLiteral("Desktop Entry");

QString desktopDirectory()
{
    return QStandardPaths::writableLocation(QStandardPaths::DesktopLocation);
}

QString storeDirectory(const QString &id)
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + QStringLiteral("/kernora/app-groups/") + id;
}

QString localPath(const QString &value)
{
    const QUrl url(value);
    if (url.scheme() == QLatin1String("desktop")) {
        QString path = url.path();
        while (path.startsWith(QLatin1Char('/'))) {
            path.remove(0, 1);
        }
        return path.isEmpty() || path.contains(QLatin1String("..")) ? QString() : QDir(desktopDirectory()).filePath(path);
    }
    if (url.isLocalFile()) {
        return url.toLocalFile();
    }
    if (url.scheme().isEmpty() && QDir::isAbsolutePath(value)) {
        return value;
    }
    return {};
}

QString groupId(const QString &path)
{
    if (!path.endsWith(QLatin1String(".desktop")) || !QFileInfo(path).isFile()) {
        return {};
    }
    const QString id = KDesktopFile(path).desktopGroup().readEntry(GroupKey, QString());
    return QUuid::fromString(QStringLiteral("{%1}").arg(id)).isNull() ? QString() : id;
}

bool isLauncher(const QString &path)
{
    if (!path.endsWith(QLatin1String(".desktop")) || !QFileInfo(path).isFile()) {
        return false;
    }
    const KDesktopFile file(path);
    const KConfigGroup entry = file.desktopGroup();
    return entry.readEntry("Type") == QLatin1String("Application") && entry.readEntry(GroupKey, QString()).isEmpty();
}

QString freeName(const QString &directory, const QString &name)
{
    if (!QFileInfo::exists(QDir(directory).filePath(name))) {
        return name;
    }
    const QString base = name.chopped(8);
    for (int i = 2; i < 1000; ++i) {
        const QString candidate = QStringLiteral("%1-%2.desktop").arg(base).arg(i);
        if (!QFileInfo::exists(QDir(directory).filePath(candidate))) {
            return candidate;
        }
    }
    return {};
}

QString adopt(const QString &path, const QString &directory)
{
    const QString name = freeName(directory, QFileInfo(path).fileName());
    if (name.isEmpty()) {
        return {};
    }
    const QString destination = QDir(directory).filePath(name);
    const bool fromDesktop = QFileInfo(path).absolutePath() == QFileInfo(desktopDirectory()).absoluteFilePath();
    if (fromDesktop ? !QFile::rename(path, destination) : !QFile::copy(path, destination)) {
        return {};
    }
    QFile::setPermissions(destination, QFile::permissions(destination) | QFile::ExeOwner | QFile::ReadOwner | QFile::WriteOwner);
    return name;
}

QString release(const QString &directory, const QString &app)
{
    const QString source = QDir(directory).filePath(app);
    const QString name = freeName(desktopDirectory(), app);
    if (name.isEmpty() || !QFile::rename(source, QDir(desktopDirectory()).filePath(name))) {
        return {};
    }
    return name;
}

QString suggestedName(const QString &directory, const QStringList &apps)
{
    const QList<QPair<QString, KLocalizedString>> names = {
        {QStringLiteral("Game"), ki18nc("@title name of a group of apps", "Games")},
        {QStringLiteral("AudioVideo"), ki18nc("@title name of a group of apps", "Media")},
        {QStringLiteral("Graphics"), ki18nc("@title name of a group of apps", "Creativity")},
        {QStringLiteral("Office"), ki18nc("@title name of a group of apps", "Productivity")},
        {QStringLiteral("Network"), ki18nc("@title name of a group of apps", "Internet")},
        {QStringLiteral("Development"), ki18nc("@title name of a group of apps", "Development")},
        {QStringLiteral("Education"), ki18nc("@title name of a group of apps", "Education")},
        {QStringLiteral("Settings"), ki18nc("@title name of a group of apps", "Settings")},
        {QStringLiteral("System"), ki18nc("@title name of a group of apps", "System")},
        {QStringLiteral("Utility"), ki18nc("@title name of a group of apps", "Tools")},
    };
    QList<QStringList> categories;
    for (const QString &app : apps) {
        categories.append(KDesktopFile(QDir(directory).filePath(app)).desktopGroup().readXdgListEntry("Categories"));
    }
    for (const auto &[category, name] : names) {
        int matches = 0;
        for (const QStringList &list : std::as_const(categories)) {
            matches += list.contains(category) ? 1 : 0;
        }
        if (matches * 2 > categories.size()) {
            return name.toString();
        }
    }
    return i18nc("@title name of a group of apps", "Apps");
}

QIcon appIcon(const QString &path)
{
    const QString name = KDesktopFile(path).readIcon();
    if (QDir::isAbsolutePath(name)) {
        return QIcon(name);
    }
    return QIcon::fromTheme(name, QIcon::fromTheme(QStringLiteral("application-x-executable")));
}

QString renderIcon(const QString &directory, const QStringList &apps)
{
    const int size = 256;
    QImage image(size, size, QImage::Format_ARGB32_Premultiplied);
    image.fill(Qt::transparent);
    QPainter painter(&image);
    painter.setRenderHint(QPainter::Antialiasing);
    painter.setRenderHint(QPainter::SmoothPixmapTransform);
    const int count = std::min<int>(apps.size(), 4);
    painter.setPen(Qt::NoPen);
    painter.setBrush(QColor(18, 18, 22, 150));
    painter.drawRoundedRect(QRectF(4, 4, 248, 248), 76, 76);
    QList<QRectF> places;
    if (count <= 1) {
        places = {QRectF(53, 53, 150, 150)};
    } else if (count == 2) {
        places = {QRectF(24, 78, 100, 100), QRectF(132, 78, 100, 100)};
    } else if (count == 3) {
        places = {QRectF(78, 22, 100, 100), QRectF(24, 134, 100, 100), QRectF(132, 134, 100, 100)};
    } else {
        places = {QRectF(24, 24, 100, 100), QRectF(132, 24, 100, 100), QRectF(24, 132, 100, 100), QRectF(132, 132, 100, 100)};
    }
    for (int i = 0; i < count; ++i) {
        const QRectF place = places.at(i);
        const QPixmap pixmap = appIcon(QDir(directory).filePath(apps.at(i))).pixmap(QSize(int(place.width()), int(place.height())) * 2);
        painter.drawPixmap(place, pixmap, QRectF(pixmap.rect()));
    }
    painter.end();
    const QDir folder(directory);
    for (const QString &old : folder.entryList({QStringLiteral("icon-*.png")}, QDir::Files)) {
        QFile::remove(folder.filePath(old));
    }
    const QString file = folder.filePath(QStringLiteral("icon-%1.png").arg(QDateTime::currentMSecsSinceEpoch()));
    return image.save(file) ? file : QString();
}

bool writeGroup(const QString &file, const QString &id, const QString &name, const QStringList &apps)
{
    const QString icon = renderIcon(storeDirectory(id), apps);
    QFile::remove(file);
    {
        KConfig config(file, KConfig::SimpleConfig);
        KConfigGroup entry(&config, EntryGroup);
        entry.writeEntry("Type", QStringLiteral("Application"));
        entry.writeEntry("Name", name);
        entry.writeEntry("Icon", icon.isEmpty() ? QStringLiteral("view-app-grid") : icon);
        entry.writeEntry("Exec", QStringLiteral("kernora-appgroup open %k"));
        entry.writeEntry("Terminal", false);
        entry.writeEntry(GroupKey, id);
        entry.writeXdgListEntry(OrderKey, apps);
        if (!config.sync()) {
            return false;
        }
    }
    return QFile::setPermissions(file, QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner | QFile::ReadGroup
                                           | QFile::ExeGroup | QFile::ReadOther | QFile::ExeOther);
}

QStringList members(const QString &file, const QString &id)
{
    const QStringList order = KDesktopFile(file).desktopGroup().readXdgListEntry(OrderKey);
    const QDir folder(storeDirectory(id));
    QStringList apps;
    for (const QString &app : order) {
        if (!app.contains(QLatin1Char('/')) && folder.exists(app) && !apps.contains(app)) {
            apps.append(app);
        }
    }
    for (const QString &app : folder.entryList({QStringLiteral("*.desktop")}, QDir::Files, QDir::Name)) {
        if (!apps.contains(app)) {
            apps.append(app);
        }
    }
    return apps;
}

void dissolve(const QString &file, const QString &id)
{
    const QString directory = storeDirectory(id);
    for (const QString &app : members(file, id)) {
        release(directory, app);
    }
    QFile::remove(file);
    QDir(directory).removeRecursively();
}
}

AppGroups::AppGroups(QObject *parent)
    : QObject(parent)
{
}

bool AppGroups::drop(const QString &target, const QStringList &sources)
{
    const QString targetPath = localPath(target);
    if (targetPath.isEmpty() || QFileInfo(targetPath).absolutePath() != QFileInfo(desktopDirectory()).absoluteFilePath()) {
        return false;
    }
    QStringList sourcePaths;
    for (const QString &source : sources) {
        const QString path = localPath(source);
        if (!path.isEmpty() && path != targetPath && isLauncher(path) && !sourcePaths.contains(path)) {
            sourcePaths.append(path);
        }
    }
    if (sourcePaths.isEmpty()) {
        return false;
    }
    QString id = groupId(targetPath);
    QStringList apps;
    QString name;
    if (id.isEmpty()) {
        if (!isLauncher(targetPath)) {
            return false;
        }
        id = QUuid::createUuid().toString(QUuid::WithoutBraces);
        if (!QDir().mkpath(storeDirectory(id))) {
            return false;
        }
        const QString first = adopt(targetPath, storeDirectory(id));
        if (first.isEmpty()) {
            QDir(storeDirectory(id)).removeRecursively();
            return false;
        }
        apps.append(first);
    } else {
        apps = members(targetPath, id);
        name = KDesktopFile(targetPath).readName();
    }
    for (const QString &path : std::as_const(sourcePaths)) {
        const QString app = adopt(path, storeDirectory(id));
        if (!app.isEmpty() && !apps.contains(app)) {
            apps.append(app);
        }
    }
    if (name.isEmpty()) {
        name = suggestedName(storeDirectory(id), apps);
    }
    return writeGroup(targetPath, id, name, apps);
}

QVariantMap AppGroups::group(const QString &groupFile) const
{
    const QString path = localPath(groupFile);
    const QString id = groupId(path);
    if (id.isEmpty()) {
        return {};
    }
    QVariantList apps;
    for (const QString &app : members(path, id)) {
        const KDesktopFile entry(QDir(storeDirectory(id)).filePath(app));
        apps.append(QVariantMap{{QStringLiteral("id"), app},
                                {QStringLiteral("name"), entry.readName()},
                                {QStringLiteral("icon"), entry.readIcon()}});
    }
    return {{QStringLiteral("file"), path}, {QStringLiteral("name"), KDesktopFile(path).readName()}, {QStringLiteral("apps"), apps}};
}

bool AppGroups::rename(const QString &groupFile, const QString &name)
{
    const QString path = localPath(groupFile);
    const QString id = groupId(path);
    const QString trimmed = name.simplified();
    if (id.isEmpty() || trimmed.isEmpty()) {
        return false;
    }
    KConfig config(path, KConfig::SimpleConfig);
    KConfigGroup(&config, EntryGroup).writeEntry("Name", trimmed);
    return config.sync();
}

void AppGroups::launch(const QString &groupFile, const QString &app, const QJSValue &callback)
{
    const QString path = localPath(groupFile);
    const QString id = groupId(path);
    QJSValue done = callback;
    if (id.isEmpty() || app.contains(QLatin1Char('/'))) {
        if (done.isCallable()) {
            done.call({false});
        }
        return;
    }
    KService::Ptr service = KService::serviceByStorageId(app);
    if (!service) {
        service = KService::Ptr(new KService(QDir(storeDirectory(id)).filePath(app)));
    }
    auto *job = new KIO::ApplicationLauncherJob(service);
    connect(job, &KJob::result, this, [job, done]() mutable {
        if (done.isCallable()) {
            done.call({job->error() == 0});
        }
    });
    job->start();
}

bool AppGroups::takeOut(const QString &groupFile, const QString &app)
{
    const QString path = localPath(groupFile);
    const QString id = groupId(path);
    if (id.isEmpty() || app.contains(QLatin1Char('/'))) {
        return false;
    }
    QStringList apps = members(path, id);
    if (!apps.contains(app) || release(storeDirectory(id), app).isEmpty()) {
        return false;
    }
    apps.removeAll(app);
    if (apps.size() <= 1) {
        dissolve(path, id);
        return true;
    }
    return writeGroup(path, id, KDesktopFile(path).readName(), apps);
}

bool AppGroups::ungroup(const QString &groupFile)
{
    const QString path = localPath(groupFile);
    const QString id = groupId(path);
    if (id.isEmpty()) {
        return false;
    }
    dissolve(path, id);
    return true;
}
