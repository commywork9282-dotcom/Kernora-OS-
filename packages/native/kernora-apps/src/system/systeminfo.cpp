// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "systeminfo.h"

#include <QDate>
#include <QFile>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocale>
#include <QOffscreenSurface>
#include <QOpenGLContext>
#include <QOpenGLFunctions>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QStorageInfo>
#include <QSysInfo>
#include <QThread>

#include <KCoreAddons>
#include <KFormat>
#include <KLocalizedString>

#include <sys/sysinfo.h>
#include <sys/utsname.h>

static QString readText(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        return QString();
    }
    return QString::fromUtf8(file.readAll()).trimmed();
}

SystemInfo::SystemInfo(QObject *parent)
    : QObject(parent)
{
    const QString release = readText(QStringLiteral("/etc/os-release"));
    static const QRegularExpression line(QStringLiteral("^([A-Z_]+)=\"?(.*?)\"?$"), QRegularExpression::MultilineOption);
    auto it = line.globalMatch(release);
    while (it.hasNext()) {
        const auto match = it.next();
        m_os.insert(match.captured(1), match.captured(2));
    }

    const QString cpuinfo = readText(QStringLiteral("/proc/cpuinfo"));
    static const QRegularExpression model(QStringLiteral("^model name\\s*:\\s*(.+)$"), QRegularExpression::MultilineOption);
    m_cpu = model.match(cpuinfo).captured(1).simplified();
    m_cpu.remove(QStringLiteral("(R)")).remove(QStringLiteral("(TM)")).remove(QStringLiteral("(tm)"));
    m_cpu = m_cpu.simplified();

    struct sysinfo info;
    if (sysinfo(&info) == 0) {
        m_memory = static_cast<qint64>(info.totalram) * info.mem_unit;
    }
}

QString SystemInfo::osBase() const
{
    const QString version = readText(QStringLiteral("/etc/debian_version"));
    return version.isEmpty() ? QStringLiteral("Debian") : QStringLiteral("Debian %1").arg(version);
}

QString SystemInfo::kernel() const
{
    struct utsname name;
    if (uname(&name) != 0) {
        return QString();
    }
    return QStringLiteral("Linux %1").arg(QString::fromLatin1(name.release));
}

QString SystemInfo::architecture() const
{
    return QSysInfo::currentCpuArchitecture();
}

int SystemInfo::cpuThreads() const
{
    return QThread::idealThreadCount();
}

QString SystemInfo::dmi(const QString &name)
{
    QString value = readText(QStringLiteral("/sys/class/dmi/id/%1").arg(name));
    static const QStringList placeholders{QStringLiteral("To Be Filled By O.E.M."), QStringLiteral("System Product Name"),
                                          QStringLiteral("Default string"), QStringLiteral("Not Specified")};
    if (placeholders.contains(value, Qt::CaseInsensitive)) {
        return QString();
    }
    return value;
}

QString SystemInfo::product() const
{
    QString product = dmi(QStringLiteral("product_name"));
    const QString version = dmi(QStringLiteral("product_version"));
    if (!version.isEmpty() && !product.contains(version) && version.length() < 20) {
        product += QLatin1Char(' ') + version;
    }
    return product;
}

QString SystemInfo::chassis() const
{
    const int type = readText(QStringLiteral("/sys/class/dmi/id/chassis_type")).toInt();
    switch (type) {
    case 8: case 9: case 10: case 14: case 31: case 32:
        return QStringLiteral("laptop");
    case 30:
        return QStringLiteral("tablet");
    case 1:
        return readText(QStringLiteral("/sys/class/dmi/id/sys_vendor")).contains(QStringLiteral("QEMU"))
            ? QStringLiteral("virtual") : QStringLiteral("desktop");
    default:
        return QStringLiteral("desktop");
    }
}

QString SystemInfo::graphics() const
{
    if (!m_graphics.isNull()) {
        return m_graphics;
    }
    m_graphics = QStringLiteral("");
    QOpenGLContext context;
    if (!context.create()) {
        return m_graphics;
    }
    QOffscreenSurface surface;
    surface.setFormat(context.format());
    surface.create();
    if (context.makeCurrent(&surface)) {
        const auto *renderer = reinterpret_cast<const char *>(context.functions()->glGetString(GL_RENDERER));
        m_graphics = QString::fromLatin1(renderer ? renderer : "");
        m_graphics.remove(QRegularExpression(QStringLiteral("\\s*\\(.*\\)$")));
        m_graphics.remove(QStringLiteral("(R)"));
        m_graphics = m_graphics.simplified();
        context.doneCurrent();
    }
    return m_graphics;
}

QString SystemInfo::windowingSystem() const
{
    return QGuiApplication::platformName().startsWith(QLatin1String("wayland")) ? QStringLiteral("Wayland")
                                                                              : QStringLiteral("X11");
}

QString SystemInfo::qtVersion() const
{
    return QString::fromLatin1(qVersion());
}

QString SystemInfo::frameworksVersion() const
{
    return KCoreAddons::versionString();
}

QString SystemInfo::hostname() const
{
    return QSysInfo::machineHostName();
}

bool SystemInfo::live() const
{
    return QFile::exists(QStringLiteral("/run/live/medium"));
}

QVariantList SystemInfo::storage() const
{
    QVariantList volumes;
    for (const QStorageInfo &volume : QStorageInfo::mountedVolumes()) {
        if (!volume.isValid() || !volume.isReady() || volume.bytesTotal() <= 0) {
            continue;
        }
        const QString device = QString::fromUtf8(volume.device());
        const QString type = QString::fromUtf8(volume.fileSystemType());
        static const QStringList skipped{QStringLiteral("tmpfs"), QStringLiteral("devtmpfs"), QStringLiteral("squashfs"),
                                         QStringLiteral("overlay"), QStringLiteral("efivarfs"), QStringLiteral("vfat")};
        const QString root = volume.rootPath();
        const bool isRoot = root == QLatin1String("/");
        if (!isRoot && (skipped.contains(type) || !device.startsWith(QLatin1String("/dev/")) || root.startsWith(QLatin1String("/boot"))
                        || root.startsWith(QLatin1String("/run/live")) || root.startsWith(QLatin1String("/snap")))) {
            continue;
        }
        volumes.append(QVariantMap{
            {QStringLiteral("name"), isRoot ? QString() : volume.displayName()},
            {QStringLiteral("mountPoint"), root},
            {QStringLiteral("device"), device},
            {QStringLiteral("total"), volume.bytesTotal()},
            {QStringLiteral("free"), volume.bytesAvailable()},
            {QStringLiteral("system"), isRoot},
        });
    }
    return volumes;
}

qint64 SystemInfo::memoryAvailable() const
{
    const QString meminfo = readText(QStringLiteral("/proc/meminfo"));
    static const QRegularExpression available(QStringLiteral("^MemAvailable:\\s*(\\d+) kB$"), QRegularExpression::MultilineOption);
    return available.match(meminfo).captured(1).toLongLong() * 1024;
}

QString SystemInfo::formatBytes(qint64 bytes) const
{
    return KFormat().formatByteSize(static_cast<double>(bytes), 1, KFormat::MetricBinaryDialect);
}

QString SystemInfo::packageVersion(const QString &package) const
{
    QFile status(QStringLiteral("/var/lib/dpkg/status"));
    if (!status.open(QIODevice::ReadOnly)) {
        return QString();
    }
    const QByteArray wanted = "Package: " + package.toUtf8();
    bool inPackage = false;
    while (!status.atEnd()) {
        const QByteArray line = status.readLine().trimmed();
        if (line.startsWith("Package: ")) {
            inPackage = line == wanted;
        } else if (inPackage && line.startsWith("Version: ")) {
            QString version = QString::fromUtf8(line.mid(9));
            version = version.section(QLatin1Char(':'), -1);
            return version.section(QLatin1Char('-'), 0, 0).section(QLatin1Char('+'), 0, 0);
        }
    }
    return QString();
}

qint64 SystemInfo::uptimeSeconds() const
{
    struct sysinfo info;
    return sysinfo(&info) == 0 ? info.uptime : 0;
}

static QString localized(const QJsonValue &value)
{
    if (value.isString()) {
        return value.toString();
    }
    const QJsonObject texts = value.toObject();
    for (const QString &language : KLocalizedString::languages()) {
        if (texts.contains(language)) {
            return texts.value(language).toString();
        }
        const QString base = language.section(QLatin1Char('_'), 0, 0);
        if (texts.contains(base)) {
            return texts.value(base).toString();
        }
    }
    return texts.value(QStringLiteral("en")).toString();
}

QVariantList SystemInfo::releaseNotes() const
{
    QFile file(QStandardPaths::locate(QStandardPaths::GenericDataLocation, QStringLiteral("kernora/whatsnew.json")));
    if (!file.open(QIODevice::ReadOnly)) {
        return {};
    }
    QVariantList releases;
    const QJsonArray entries = QJsonDocument::fromJson(file.readAll()).array();
    for (const QJsonValue &entry : entries) {
        const QJsonObject release = entry.toObject();
        QVariantList items;
        const QJsonArray changes = release.value(QStringLiteral("items")).toArray();
        for (const QJsonValue &change : changes) {
            const QJsonObject item = change.toObject();
            items.append(QVariantMap{{QStringLiteral("icon"), item.value(QStringLiteral("icon")).toString()},
                                     {QStringLiteral("title"), localized(item.value(QStringLiteral("title")))},
                                     {QStringLiteral("text"), localized(item.value(QStringLiteral("text")))}});
        }
        const QString id = release.value(QStringLiteral("id")).toString();
        releases.append(QVariantMap{{QStringLiteral("id"), id},
                                    {QStringLiteral("date"), QLocale().toString(QDate::fromString(id, Qt::ISODate), QStringLiteral("d MMMM yyyy"))},
                                    {QStringLiteral("items"), items}});
    }
    return releases;
}
