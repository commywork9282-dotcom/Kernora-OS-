// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "android.h"
#include "apk.h"

#include <KDesktopFile>

#include <QClipboard>
#include <QCollator>
#include <QCryptographicHash>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusServiceWatcher>
#include <QDateTime>
#include <QDir>
#include <QFileInfo>
#include <QFileSystemWatcher>
#include <QGuiApplication>
#include <QJSEngine>
#include <QLocale>
#include <QPointer>
#include <QProcess>
#include <QStandardPaths>
#include <QThreadPool>
#include <QTimer>

#include <algorithm>
#include <functional>
#include <memory>

namespace
{
const QString SessionService = QStringLiteral("id.waydro.Session");
const QString Waydroid = QStringLiteral("waydroid");
const QString SessionStarter = QStringLiteral("/usr/libexec/kernora-android-session");
constexpr int IconSize = 192;
constexpr int InstallTimeout = 10 * 60 * 1000;
constexpr int InstallPoll = 2000;
constexpr int InstallChecks = 30;
constexpr int IconRetry = 2000;
constexpr int IconRetries = 15;

void reply(QObject *context, const QJSValue &callback, const QJSValueList &arguments)
{
    if (callback.isCallable() && qjsEngine(context)) {
        QJSValue function = callback;
        function.call(arguments);
    }
}

QProcess *quietProcess(QObject *parent, const QString &program, const QStringList &arguments)
{
    auto *process = new QProcess(parent);
    process->setProgram(program);
    process->setArguments(arguments);
    QProcessEnvironment environment = QProcessEnvironment::systemEnvironment();
    environment.insert(QStringLiteral("KERNORA_ANDROID_QUIET"), QStringLiteral("1"));
    process->setProcessEnvironment(environment);
    return process;
}

void run(QObject *context, QProcess *process, int timeout, std::function<void(bool, const QString &)> done)
{
    auto finished = std::make_shared<bool>(false);
    auto finish = [process, finished, done](bool ok) {
        if (*finished) {
            return;
        }
        *finished = true;
        done(ok, QString::fromUtf8(process->readAllStandardOutput()));
        process->deleteLater();
    };
    QObject::connect(process, &QProcess::finished, context, [finish](int code, QProcess::ExitStatus status) {
        finish(status == QProcess::NormalExit && code == 0);
    });
    QObject::connect(process, &QProcess::errorOccurred, context, [finish](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart) {
            finish(false);
        }
    });
    if (timeout > 0) {
        QTimer::singleShot(timeout, process, [process] {
            process->kill();
        });
    }
    process->start();
    process->closeWriteChannel();
}

QString iconUrl(const QString &path)
{
    QUrl url = QUrl::fromLocalFile(path);
    const QFileInfo info(path);
    if (info.exists()) {
        url.setQuery(QStringLiteral("v=") + QString::number(info.lastModified().toMSecsSinceEpoch()) + QLatin1Char('-')
                     + QString::number(info.size()));
    }
    return url.toString();
}

bool listed(const QString &output, const QString &package)
{
    const QString wanted = QStringLiteral("packageName: ") + package;
    const QStringList lines = output.split(QLatin1Char('\n'));
    for (const QString &line : lines) {
        if (line.trimmed() == wanted) {
            return true;
        }
    }
    return false;
}
}

Android::Android(QObject *parent)
    : QObject(parent)
    , m_watcher(new QFileSystemWatcher(this))
    , m_session(new QDBusServiceWatcher(SessionService, QDBusConnection::sessionBus(), QDBusServiceWatcher::WatchForOwnerChange, this))
{
    const QString folder = applicationsFolder();
    QDir().mkpath(folder);
    m_watcher->addPath(folder);
    connect(m_watcher, &QFileSystemWatcher::directoryChanged, this, [this] {
        scan();
        QTimer::singleShot(IconRetry * 3, this, &Android::scan);
    });
    connect(m_session, &QDBusServiceWatcher::serviceOwnerChanged, this, [this](const QString &, const QString &, const QString &owner) {
        const bool running = !owner.isEmpty();
        if (running != m_running) {
            m_running = running;
            Q_EMIT runningChanged();
        }
    });
    m_running = QDBusConnection::sessionBus().interface()->isServiceRegistered(SessionService);
    scan();
}

QString Android::applicationsFolder() const
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + QStringLiteral("/applications");
}

void Android::scan()
{
    const QDir folder(applicationsFolder());
    const QStringList files = folder.entryList({QStringLiteral("waydroid.*.desktop")}, QDir::Files);
    QList<QVariantMap> found;
    bool iconMissing = false;
    for (const QString &name : files) {
        KDesktopFile desktop(folder.filePath(name));
        if (desktop.noDisplay()) {
            continue;
        }
        const QString icon = desktop.readIcon();
        if (icon.startsWith(QLatin1Char('/')) && !QFileInfo::exists(icon)) {
            iconMissing = true;
        }
        found.append({{QStringLiteral("package"), name.mid(9, name.size() - 17)},
                      {QStringLiteral("name"), desktop.readName()},
                      {QStringLiteral("icon"), icon.startsWith(QLatin1Char('/')) ? iconUrl(icon) : icon}});
    }
    QCollator collator;
    std::sort(found.begin(), found.end(), [&collator](const QVariantMap &a, const QVariantMap &b) {
        return collator.compare(a.value(QStringLiteral("name")).toString(), b.value(QStringLiteral("name")).toString()) < 0;
    });
    QVariantList apps;
    for (const QVariantMap &app : found) {
        apps.append(app);
    }
    if (apps != m_apps) {
        m_apps = apps;
        Q_EMIT appsChanged();
    }
    if (iconMissing && m_iconRetries < IconRetries) {
        ++m_iconRetries;
        QTimer::singleShot(IconRetry, this, &Android::scan);
    } else if (!iconMissing) {
        m_iconRetries = 0;
    }
}

QString Android::iconCache(const QString &path)
{
    const QFileInfo info(path);
    const QString cache = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + QStringLiteral("/icons");
    QDir().mkpath(cache);
    const QByteArray key = (info.absoluteFilePath() + QString::number(info.lastModified().toMSecsSinceEpoch())).toUtf8();
    return cache + QLatin1Char('/') + QString::fromLatin1(QCryptographicHash::hash(key, QCryptographicHash::Sha1).toHex()) + QStringLiteral(".png");
}

QVariantMap Android::inspect(const QUrl &file) const
{
    const QString path = file.isLocalFile() ? file.toLocalFile() : file.toString();
    const QFileInfo info(path);
    const Apk::Package package = Apk::read(path, QLocale::system().name(), IconSize);
    QVariantMap result{{QStringLiteral("error"), package.error},
                       {QStringLiteral("package"), package.packageName},
                       {QStringLiteral("label"), package.label},
                       {QStringLiteral("versionName"), package.versionName},
                       {QStringLiteral("versionCode"), package.versionCode},
                       {QStringLiteral("minSdk"), package.minSdk},
                       {QStringLiteral("targetSdk"), package.targetSdk},
                       {QStringLiteral("abis"), package.abis},
                       {QStringLiteral("compatible"), package.abis.isEmpty() || package.abis.contains(QLatin1String("x86_64"))
                            || package.abis.contains(QLatin1String("x86"))},
                       {QStringLiteral("size"), info.size()},
                       {QStringLiteral("fileName"), info.fileName()},
                       {QStringLiteral("icon"), QString()}};
    if (!package.icon.isNull()) {
        const QString target = iconCache(path);
        if (package.icon.save(target, "PNG")) {
            result.insert(QStringLiteral("icon"), QUrl::fromLocalFile(target).toString());
        }
    }
    return result;
}

void Android::iconOf(const QUrl &file, const QJSValue &callback)
{
    const QString path = file.isLocalFile() ? file.toLocalFile() : file.toString();
    const QString target = iconCache(path);
    if (QFileInfo::exists(target)) {
        reply(this, callback, {QJSValue(QUrl::fromLocalFile(target).toString())});
        return;
    }
    const int request = ++m_nextRequest;
    m_iconRequests.insert(request, callback);
    const QString language = QLocale::system().name();
    QPointer<Android> self(this);
    QThreadPool::globalInstance()->start([self, request, path, target, language] {
        const Apk::Package package = Apk::read(path, language, IconSize);
        const bool saved = !package.icon.isNull() && package.icon.save(target, "PNG");
        QMetaObject::invokeMethod(QCoreApplication::instance(), [self, request, target, saved] {
            if (!self) {
                return;
            }
            const QJSValue callback = self->m_iconRequests.take(request);
            reply(self, callback, {QJSValue(saved ? QUrl::fromLocalFile(target).toString() : QString())});
        }, Qt::QueuedConnection);
    });
}

bool Android::hasApp(const QString &package) const
{
    return QFileInfo::exists(applicationsFolder() + QStringLiteral("/waydroid.") + package + QStringLiteral(".desktop"));
}

void Android::waitForPackage(const QString &package, const QJSValue &callback, int attempts)
{
    run(this, quietProcess(this, Waydroid, {QStringLiteral("app"), QStringLiteral("list")}), 60000,
        [this, package, callback, attempts](bool, const QString &output) {
            const bool found = listed(output, package);
            if (found || attempts <= 1) {
                reply(this, callback, {QJSValue(found)});
                return;
            }
            QTimer::singleShot(InstallPoll, this, [this, package, callback, attempts] {
                waitForPackage(package, callback, attempts - 1);
            });
        });
}

void Android::install(const QUrl &file, const QString &package, const QJSValue &callback)
{
    const QString path = file.isLocalFile() ? file.toLocalFile() : file.toString();
    run(this, quietProcess(this, Waydroid, {QStringLiteral("app"), QStringLiteral("install"), path}), InstallTimeout,
        [this, package, callback](bool ok, const QString &) {
            if (!ok) {
                reply(this, callback, {QJSValue(false)});
                return;
            }
            QTimer::singleShot(1000, this, [this, package, callback] {
                waitForPackage(package, callback, InstallChecks);
            });
        });
}

bool Android::uninstall(const QString &package)
{
    return QProcess::startDetached(Waydroid, {QStringLiteral("app"), QStringLiteral("intent"), QStringLiteral("android.intent.action.DELETE"),
                                              QStringLiteral("package:") + package});
}

bool Android::launch(const QString &package)
{
    return QProcess::startDetached(Waydroid, {QStringLiteral("app"), QStringLiteral("launch"), package});
}

bool Android::openSettings()
{
    return launch(QStringLiteral("com.android.settings"));
}

void Android::start(const QJSValue &callback)
{
    run(this, quietProcess(this, SessionStarter, {}), 0, [this, callback](bool ok, const QString &) {
        reply(this, callback, {QJSValue(ok)});
    });
}

void Android::stop()
{
    QProcess::startDetached(Waydroid, {QStringLiteral("session"), QStringLiteral("stop")});
}

void Android::copyText(const QString &text)
{
    QGuiApplication::clipboard()->setText(text);
}
