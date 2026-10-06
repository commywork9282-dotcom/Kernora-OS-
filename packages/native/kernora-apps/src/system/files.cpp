// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "files.h"

#include <memory>

#include <QCollator>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCall>
#include <QDateTime>
#include <QDir>
#include <QDirIterator>
#include <QImageReader>
#include <QJsonDocument>
#include <QJsonObject>
#include <QFile>
#include <QFileInfo>
#include <QJSEngine>
#include <QLocale>
#include <QMimeDatabase>
#include <QProcess>
#include <QRegularExpression>
#include <QSaveFile>
#include <QStandardPaths>

#include <KConfig>
#include <KConfigGroup>
#include <KFormat>
#include <KIO/CopyJob>
#include <KIO/DeleteJob>
#include <KIO/EmptyTrashJob>
#include <KIO/Global>
#include <KLocalizedString>
#include <KPropertiesDialog>

Files::Files(QObject *parent)
    : QObject(parent)
{
}

void Files::report(const QJSValue &callback, bool ok, const QString &message)
{
    if (callback.isCallable() && qjsEngine(this)) {
        QJSValue function = callback;
        function.call({QJSValue(ok), QJSValue(message)});
    }
}

QVariantMap Files::info(const QUrl &url) const
{
    const QFileInfo file(url.toLocalFile());
    const QMimeType mime = QMimeDatabase().mimeTypeForUrl(url);
    return {{QStringLiteral("name"), file.fileName()},
            {QStringLiteral("path"), file.absoluteFilePath()},
            {QStringLiteral("folder"), QUrl::fromLocalFile(file.absolutePath())},
            {QStringLiteral("size"), file.size()},
            {QStringLiteral("sizeText"), file.isDir() ? QString() : KFormat().formatByteSize(file.size())},
            {QStringLiteral("modified"), file.lastModified()},
            {QStringLiteral("mimeType"), mime.name()},
            {QStringLiteral("typeName"), mime.comment()},
            {QStringLiteral("icon"), KIO::iconNameForUrl(url)},
            {QStringLiteral("isDir"), file.isDir()},
            {QStringLiteral("writable"), file.isWritable()},
            {QStringLiteral("exists"), file.exists()}};
}

QString Files::mimeType(const QUrl &url) const
{
    return QMimeDatabase().mimeTypeForUrl(url).name();
}

QString Files::iconName(const QUrl &url) const
{
    return KIO::iconNameForUrl(url);
}

bool Files::exists(const QUrl &url) const
{
    return QFileInfo::exists(url.toLocalFile());
}

QVariantMap Files::readText(const QUrl &url) const
{
    QFile file(url.toLocalFile());
    if (!file.open(QIODevice::ReadOnly)) {
        return {{QStringLiteral("ok"), false}, {QStringLiteral("error"), file.errorString()}};
    }
    const QByteArray data = file.readAll();
    const bool binary = data.left(8192).contains('\0');
    return {{QStringLiteral("ok"), !binary},
            {QStringLiteral("text"), binary ? QString() : QString::fromUtf8(data)},
            {QStringLiteral("error"), binary ? i18n("This file is not a text file.") : QString()}};
}

bool Files::writeText(const QUrl &url, const QString &text)
{
    QSaveFile file(url.toLocalFile());
    if (!file.open(QIODevice::WriteOnly)) {
        return false;
    }
    file.write(text.toUtf8());
    return file.commit();
}

void Files::trash(const QList<QUrl> &urls, const QJSValue &callback)
{
    auto *job = KIO::trash(urls);
    connect(job, &KJob::result, this, [this, callback](KJob *job) {
        report(callback, job->error() == 0, job->errorString());
    });
}

void Files::remove(const QList<QUrl> &urls, const QJSValue &callback)
{
    auto *job = KIO::del(urls);
    connect(job, &KJob::result, this, [this, callback](KJob *job) {
        report(callback, job->error() == 0, job->errorString());
    });
}

void Files::rename(const QUrl &url, const QString &newName, const QJSValue &callback)
{
    const QString name = newName.trimmed();
    if (name.isEmpty() || name.contains(QLatin1Char('/'))) {
        report(callback, false, i18n("A name cannot be empty or contain “/”."));
        return;
    }
    QUrl target = url.adjusted(QUrl::RemoveFilename);
    target.setPath(target.path() + name);
    auto *job = KIO::moveAs(url, target, KIO::HideProgressInfo);
    connect(job, &KJob::result, this, [this, callback](KJob *job) {
        report(callback, job->error() == 0, job->errorString());
    });
}

void Files::copy(const QList<QUrl> &urls, const QUrl &destination, const QJSValue &callback)
{
    auto *job = KIO::copy(urls, destination);
    connect(job, &KJob::result, this, [this, callback](KJob *job) {
        report(callback, job->error() == 0, job->errorString());
    });
}

void Files::showProperties(const QList<QUrl> &urls)
{
    if (urls.isEmpty()) {
        return;
    }
    KPropertiesDialog::showDialog(urls, nullptr, false);
}

QUrl Files::trashFolder() const
{
    return QUrl::fromLocalFile(QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + QStringLiteral("/Trash/files"));
}

QVariantMap Files::trashInfo(const QUrl &url) const
{
    const QFileInfo file(url.toLocalFile());
    const QString info = file.absolutePath() + QStringLiteral("/../info/") + file.fileName() + QStringLiteral(".trashinfo");
    KConfig config(info, KConfig::SimpleConfig);
    const KConfigGroup group = config.group(QStringLiteral("Trash Info"));
    const QString path = QUrl::fromPercentEncoding(group.readEntry("Path", QString()).toUtf8());
    return {{QStringLiteral("originalPath"), path},
            {QStringLiteral("originalFolder"), QFileInfo(path).absolutePath()},
            {QStringLiteral("deleted"), QDateTime::fromString(group.readEntry("DeletionDate", QString()), Qt::ISODate)}};
}

void Files::restore(const QList<QUrl> &urls, const QJSValue &callback)
{
    struct Progress {
        int remaining = 0;
        QStringList errors;
    };
    auto progress = std::make_shared<Progress>();
    QList<std::pair<QUrl, QString>> moves;
    for (const QUrl &url : urls) {
        const QString path = trashInfo(url).value(QStringLiteral("originalPath")).toString();
        if (!path.isEmpty()) {
            moves.append({url, path});
        }
    }
    if (moves.isEmpty()) {
        report(callback, false, i18n("Where these files came from is not known."));
        return;
    }
    progress->remaining = moves.size();
    for (const auto &[url, path] : std::as_const(moves)) {
        QDir().mkpath(QFileInfo(path).absolutePath());
        const QFileInfo file(url.toLocalFile());
        const QString info = file.absolutePath() + QStringLiteral("/../info/") + file.fileName() + QStringLiteral(".trashinfo");
        auto *job = KIO::moveAs(url, QUrl::fromLocalFile(path), KIO::HideProgressInfo);
        connect(job, &KJob::result, this, [this, callback, progress, info](KJob *job) {
            if (job->error()) {
                progress->errors.append(job->errorString());
            } else {
                QFile::remove(info);
            }
            if (--progress->remaining == 0) {
                report(callback, progress->errors.isEmpty(), progress->errors.join(QLatin1Char('\n')));
            }
        });
    }
}

void Files::createFolder(const QUrl &parent, const QString &name, const QJSValue &callback)
{
    const QString clean = name.trimmed();
    if (clean.isEmpty() || clean.contains(QLatin1Char('/'))) {
        report(callback, false, i18n("A name cannot be empty or contain “/”."));
        return;
    }
    const QString path = QDir(parent.toLocalFile()).filePath(clean);
    if (QFileInfo::exists(path)) {
        report(callback, false, i18n("“%1” already exists.", clean));
        return;
    }
    const bool ok = QDir().mkdir(path);
    report(callback, ok, ok ? QUrl::fromLocalFile(path).toString() : i18n("The folder could not be created."));
}

void Files::move(const QList<QUrl> &urls, const QUrl &destination, const QJSValue &callback)
{
    auto *job = KIO::move(urls, destination);
    connect(job, &KJob::result, this, [this, callback](KJob *job) {
        report(callback, job->error() == 0, job->errorString());
    });
}

QList<QUrl> Files::conflicts(const QList<QUrl> &urls, const QUrl &destination) const
{
    QList<QUrl> found;
    for (const QUrl &url : urls) {
        QUrl target = destination.adjusted(QUrl::StripTrailingSlash);
        target.setPath(target.path() + QLatin1Char('/') + url.fileName());
        if (exists(target)) {
            found.append(url);
        }
    }
    return found;
}

void Files::transfer(const QList<QUrl> &urls, const QUrl &destination, bool move, const QString &onConflict, const QJSValue &callback)
{
    if (urls.isEmpty()) {
        report(callback, true, QString());
        return;
    }
    const KIO::JobFlags flags = onConflict == QLatin1String("replace") ? KIO::Overwrite : KIO::DefaultFlags;
    KIO::CopyJob *job = move ? KIO::move(urls, destination, flags) : KIO::copy(urls, destination, flags);
    job->setUiDelegate(nullptr);
    if (onConflict == QLatin1String("rename")) {
        job->setAutoRename(true);
    } else if (onConflict == QLatin1String("replace")) {
        job->setWriteIntoExistingDirectories(true);
    }
    connect(job, &KJob::result, this, [this, callback](KJob *job) {
        report(callback, job->error() == 0, job->errorString());
    });
}

qint64 Files::trashSize() const
{
    const QString trash = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + QStringLiteral("/Trash/files");
    qint64 total = 0;
    QDirIterator it(trash, QDir::Files | QDir::Hidden | QDir::System | QDir::NoDotAndDotDot, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        it.next();
        total += it.fileInfo().size();
    }
    return total;
}

void Files::emptyTrash(const QJSValue &callback)
{
    auto *job = KIO::emptyTrash();
    connect(job, &KJob::result, this, [this, callback](KJob *job) {
        report(callback, job->error() == 0, job->errorString());
    });
}

bool Files::isArchive(const QUrl &url) const
{
    static const QStringList types{QStringLiteral("application/zip"), QStringLiteral("application/x-tar"),
                                   QStringLiteral("application/x-compressed-tar"), QStringLiteral("application/x-bzip-compressed-tar"),
                                   QStringLiteral("application/x-xz-compressed-tar"), QStringLiteral("application/x-zstd-compressed-tar"),
                                   QStringLiteral("application/x-7z-compressed"), QStringLiteral("application/vnd.rar"),
                                   QStringLiteral("application/x-rar"), QStringLiteral("application/x-cd-image"),
                                   QStringLiteral("application/x-iso9660-image")};
    return types.contains(mimeType(url));
}

void Files::compress(const QList<QUrl> &urls, const QJSValue &callback)
{
    if (urls.isEmpty()) {
        return;
    }
    const QFileInfo first(urls.first().toLocalFile());
    const QString folder = first.absolutePath();
    const QString base = urls.size() == 1 ? first.completeBaseName().isEmpty() ? first.fileName() : first.completeBaseName()
                                          : i18nc("name of an archive of several files", "Archive");
    const QString target = uniqueName(QUrl::fromLocalFile(folder), base + QStringLiteral(".zip"));
    QStringList arguments{QStringLiteral("-a"), QStringLiteral("-c"), QStringLiteral("-f"), target, QStringLiteral("-C"), folder, QStringLiteral("--")};
    for (const QUrl &url : urls) {
        arguments.append(QFileInfo(url.toLocalFile()).fileName());
    }
    auto *process = new QProcess(this);
    connect(process, &QProcess::finished, this, [this, process, callback](int code) {
        report(callback, code == 0, QString::fromUtf8(process->readAllStandardError()));
        process->deleteLater();
    });
    process->start(QStringLiteral("bsdtar"), arguments);
}

void Files::extract(const QUrl &archive, const QJSValue &callback)
{
    const QFileInfo file(archive.toLocalFile());
    QString base = file.fileName();
    for (const QString &suffix : {QStringLiteral(".tar.gz"), QStringLiteral(".tar.xz"), QStringLiteral(".tar.bz2"),
                                  QStringLiteral(".tar.zst"), QStringLiteral(".tgz")}) {
        if (base.endsWith(suffix)) {
            base.chop(suffix.size());
            break;
        }
    }
    if (base == file.fileName()) {
        base = file.completeBaseName();
    }
    const QString target = uniqueName(QUrl::fromLocalFile(file.absolutePath()), base);
    QDir().mkpath(target);
    auto *process = new QProcess(this);
    connect(process, &QProcess::finished, this, [this, process, callback, target](int code) {
        report(callback, code == 0, code == 0 ? target : QString::fromUtf8(process->readAllStandardError()));
        process->deleteLater();
    });
    process->start(QStringLiteral("bsdtar"), {QStringLiteral("-x"), QStringLiteral("-f"), file.absoluteFilePath(), QStringLiteral("-C"), target});
}

QUrl Files::standardFolder(const QString &name) const
{
    static const QHash<QString, QStandardPaths::StandardLocation> locations{
        {QStringLiteral("home"), QStandardPaths::HomeLocation},
        {QStringLiteral("desktop"), QStandardPaths::DesktopLocation},
        {QStringLiteral("documents"), QStandardPaths::DocumentsLocation},
        {QStringLiteral("downloads"), QStandardPaths::DownloadLocation},
        {QStringLiteral("music"), QStandardPaths::MusicLocation},
        {QStringLiteral("pictures"), QStandardPaths::PicturesLocation},
        {QStringLiteral("videos"), QStandardPaths::MoviesLocation},
    };
    const QString path = QStandardPaths::writableLocation(locations.value(name, QStandardPaths::HomeLocation));
    return QUrl::fromLocalFile(path);
}

QList<QUrl> Files::siblings(const QUrl &url, const QString &mimePrefix) const
{
    const QFileInfo file(url.toLocalFile());
    QDir folder = file.absoluteDir();
    QMimeDatabase mimes;
    QStringList names;
    for (const QFileInfo &entry : folder.entryInfoList(QDir::Files | QDir::Readable)) {
        if (mimes.mimeTypeForFile(entry, QMimeDatabase::MatchExtension).name().startsWith(mimePrefix)) {
            names.append(entry.fileName());
        }
    }
    QCollator collator;
    collator.setNumericMode(true);
    std::sort(names.begin(), names.end(), [&collator](const QString &a, const QString &b) {
        return collator.compare(a, b) < 0;
    });
    QList<QUrl> urls;
    for (const QString &name : std::as_const(names)) {
        urls.append(QUrl::fromLocalFile(folder.filePath(name)));
    }
    return urls;
}

QString Files::uniqueName(const QUrl &folder, const QString &baseName) const
{
    const QDir dir(folder.toLocalFile());
    if (!dir.exists(baseName)) {
        return dir.filePath(baseName);
    }
    const QFileInfo name(baseName);
    const QString stem = name.completeBaseName().isEmpty() ? baseName : name.completeBaseName();
    const QString suffix = name.suffix().isEmpty() ? QString() : QLatin1Char('.') + name.suffix();
    for (int i = 2; i < 1000; ++i) {
        const QString candidate = QStringLiteral("%1 (%2)%3").arg(stem).arg(i).arg(suffix);
        if (!dir.exists(candidate)) {
            return dir.filePath(candidate);
        }
    }
    return dir.filePath(baseName);
}

static void evaluateShellScript(const QString &script)
{
    QDBusMessage message = QDBusMessage::createMethodCall(QStringLiteral("org.kde.plasmashell"), QStringLiteral("/PlasmaShell"),
                                                          QStringLiteral("org.kde.PlasmaShell"), QStringLiteral("evaluateScript"));
    message.setArguments({script});
    QDBusConnection::sessionBus().asyncCall(message);
}

void Files::setWallpaper(const QUrl &image)
{
    const QString path = image.toLocalFile().replace(QLatin1Char('\\'), QStringLiteral("\\\\")).replace(QLatin1Char('"'), QStringLiteral("\\\""));
    evaluateShellScript(QStringLiteral(
        "for (const d of desktops()) {"
        "  d.wallpaperPlugin = 'org.kde.image';"
        "  d.currentConfigGroup = ['Wallpaper', 'org.kde.image', 'General'];"
        "  d.writeConfig('Image', 'file://%1');"
        "  d.writeConfig('FillMode', 2);"
        "}").arg(path));
}

void Files::setLiveWallpaper(const QString &plugin)
{
    static const QRegularExpression valid(QStringLiteral("^org\\.kernora\\.[a-z0-9]+$"));
    const QString id = valid.match(plugin).hasMatch() ? plugin : QStringLiteral("org.kernora.shapes");
    evaluateShellScript(QStringLiteral(
        "for (const d of desktops()) {"
        "  d.wallpaperPlugin = '%1';"
        "}").arg(id));
}

void Files::setLockScreenWallpaper(const QUrl &image)
{
    KConfig config(QStringLiteral("kscreenlockerrc"));
    KConfigGroup greeter = config.group(QStringLiteral("Greeter"));
    if (image.isEmpty()) {
        greeter.deleteEntry("WallpaperPlugin", KConfig::Notify);
        greeter.group(QStringLiteral("Wallpaper")).deleteGroup(KConfig::Notify);
    } else {
        greeter.writeEntry("WallpaperPlugin", QStringLiteral("org.kde.image"), KConfig::Notify);
        KConfigGroup general = greeter.group(QStringLiteral("Wallpaper")).group(QStringLiteral("org.kde.image")).group(QStringLiteral("General"));
        general.writeEntry("Image", image.toString(), KConfig::Notify);
        general.writeEntry("FillMode", 2, KConfig::Notify);
    }
    config.sync();
}

static QString largestImage(const QString &folder)
{
    QString best;
    qint64 bestArea = -1;
    const QDir images(folder);
    const QStringList filters{QStringLiteral("*.png"), QStringLiteral("*.jpg"), QStringLiteral("*.jpeg"),
                              QStringLiteral("*.webp"), QStringLiteral("*.svg"), QStringLiteral("*.avif")};
    for (const QFileInfo &file : images.entryInfoList(filters, QDir::Files)) {
        const QStringList size = file.completeBaseName().split(QLatin1Char('x'));
        qint64 area = 0;
        if (size.size() == 2) {
            area = size.at(0).toLongLong() * size.at(1).toLongLong();
        } else {
            const QSize read = QImageReader(file.absoluteFilePath()).size();
            area = qint64(read.width()) * read.height();
        }
        if (area > bestArea) {
            bestArea = area;
            best = file.absoluteFilePath();
        }
    }
    return best;
}

static QString localizedName(const QJsonObject &plugin)
{
    const QString language = QLocale().name();
    for (const QString &key : {QStringLiteral("Name[%1]").arg(language), QStringLiteral("Name[%1]").arg(language.section(QLatin1Char('_'), 0, 0))}) {
        const QString value = plugin.value(key).toString();
        if (!value.isEmpty()) {
            return value;
        }
    }
    return plugin.value(QStringLiteral("Name")).toString();
}

QVariantList Files::liveWallpapers() const
{
    QVariantList list;
    QStringList seen;
    const QStringList roots = QStandardPaths::locateAll(QStandardPaths::GenericDataLocation, QStringLiteral("plasma/wallpapers"), QStandardPaths::LocateDirectory);
    for (const QString &root : roots) {
        const QDir dir(root);
        for (const QFileInfo &entry : dir.entryInfoList({QStringLiteral("org.kernora.*")}, QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name)) {
            const QString scene = entry.absoluteFilePath() + QStringLiteral("/contents/ui/Scene.qml");
            if (seen.contains(entry.fileName()) || !QFileInfo::exists(scene)) {
                continue;
            }
            QFile metadata(entry.absoluteFilePath() + QStringLiteral("/metadata.json"));
            QString name = entry.fileName();
            if (metadata.open(QIODevice::ReadOnly)) {
                const QString localized = localizedName(QJsonDocument::fromJson(metadata.readAll()).object().value(QStringLiteral("KPlugin")).toObject());
                if (!localized.isEmpty()) {
                    name = localized;
                }
            }
            seen.append(entry.fileName());
            const QVariantMap item{{QStringLiteral("id"), entry.fileName()},
                                   {QStringLiteral("name"), name},
                                   {QStringLiteral("scene"), QUrl::fromLocalFile(scene)}};
            if (entry.fileName() == QLatin1String("org.kernora.shapes")) {
                list.prepend(item);
            } else {
                list.append(item);
            }
        }
    }
    return list;
}

QVariantList Files::wallpapers() const
{
    QVariantList list;
    QStringList seen;
    QStringList roots = QStandardPaths::locateAll(QStandardPaths::GenericDataLocation, QStringLiteral("wallpapers"), QStandardPaths::LocateDirectory);
    std::reverse(roots.begin(), roots.end());
    for (const QString &root : std::as_const(roots)) {
        const QDir dir(root);
        for (const QFileInfo &entry : dir.entryInfoList(QDir::Dirs | QDir::Files | QDir::NoDotAndDotDot, QDir::Name)) {
            if (seen.contains(entry.fileName())) {
                continue;
            }
            QString name;
            QString image;
            QString preview;
            if (entry.isDir()) {
                image = largestImage(entry.absoluteFilePath() + QStringLiteral("/contents/images"));
                if (image.isEmpty()) {
                    continue;
                }
                QFile metadata(entry.absoluteFilePath() + QStringLiteral("/metadata.json"));
                if (metadata.open(QIODevice::ReadOnly)) {
                    name = localizedName(QJsonDocument::fromJson(metadata.readAll()).object().value(QStringLiteral("KPlugin")).toObject());
                }
                const QString screenshot = entry.absoluteFilePath() + QStringLiteral("/contents/screenshot.png");
                preview = QFileInfo::exists(screenshot) ? screenshot : image;
            } else if (!QImageReader::imageFormat(entry.absoluteFilePath()).isEmpty()) {
                image = entry.absoluteFilePath();
                preview = image;
            } else {
                continue;
            }
            if (name.isEmpty()) {
                name = entry.completeBaseName();
            }
            seen.append(entry.fileName());
            list.append(QVariantMap{{QStringLiteral("name"), name},
                                    {QStringLiteral("image"), QUrl::fromLocalFile(image)},
                                    {QStringLiteral("preview"), QUrl::fromLocalFile(preview)}});
        }
    }
    return list;
}
