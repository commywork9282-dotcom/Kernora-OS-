// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "appiconsync.h"
#include "appicons.h"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QHash>
#include <QRegularExpression>
#include <QSaveFile>
#include <QSet>
#include <QStandardPaths>

#include <KConfig>
#include <KConfigGroup>
#include <KService>
#include <KSycoca>

#include <algorithm>

namespace
{
constexpr int SettleDelay = 1500;
constexpr int Version = 1;

QString userIcons()
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + QStringLiteral("/icons");
}

QStringList iconBases()
{
    QStringList bases = QStandardPaths::locateAll(QStandardPaths::GenericDataLocation, QStringLiteral("icons"), QStandardPaths::LocateDirectory);
    bases.removeDuplicates();
    return bases;
}

QStringList systemIconBases()
{
    QStringList bases = iconBases();
    bases.removeAll(userIcons());
    return bases;
}

QSet<QString> kernoraIcons()
{
    QSet<QString> names;
    for (const QString &base : systemIconBases()) {
        QDirIterator it(base + QStringLiteral("/Kernora/scalable"), {QStringLiteral("*.svg")}, QDir::Files, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            names.insert(QFileInfo(it.next()).completeBaseName());
        }
    }
    return names;
}

QStringList inheritedThemes()
{
    for (const QString &base : systemIconBases()) {
        const QString path = base + QStringLiteral("/Kernora/index.theme");
        if (!QFileInfo::exists(path)) {
            continue;
        }
        KConfig index(path, KConfig::SimpleConfig);
        const QStringList inherits = index.group(QStringLiteral("Icon Theme")).readEntry("Inherits", QStringList());
        if (!inherits.isEmpty()) {
            return inherits;
        }
    }
    return {QStringLiteral("breeze-dark"), QStringLiteral("breeze"), QStringLiteral("hicolor")};
}

int score(const QFileInfo &file, const QString &themeDir)
{
    const QString suffix = file.suffix().toLower();
    if (suffix == QLatin1String("svg") || suffix == QLatin1String("svgz")) {
        return 100000;
    }
    static const QRegularExpression size(QStringLiteral("(?:^|/)(\\d+)(?:x\\d+)?(?:@(\\d+)x?)?(?:/|$)"));
    int best = 0;
    auto matches = size.globalMatch(QDir(themeDir).relativeFilePath(file.absolutePath()));
    while (matches.hasNext()) {
        const QRegularExpressionMatch match = matches.next();
        best = std::max(best, match.captured(1).toInt() * std::max(1, match.captured(2).toInt()));
    }
    return best;
}

QHash<QString, QString> findSources(const QSet<QString> &names)
{
    QHash<QString, QString> sources;
    for (const QString &theme : inheritedThemes()) {
        QHash<QString, QPair<int, QString>> found;
        for (const QString &base : iconBases()) {
            const QString themeDir = base + QLatin1Char('/') + theme;
            if (!QFileInfo(themeDir).isDir()) {
                continue;
            }
            QDirIterator it(themeDir, {QStringLiteral("*.png"), QStringLiteral("*.svg"), QStringLiteral("*.svgz")}, QDir::Files,
                            QDirIterator::Subdirectories);
            while (it.hasNext()) {
                const QFileInfo info(it.next());
                const QString name = info.completeBaseName();
                if (!names.contains(name) || sources.contains(name) || !info.absolutePath().contains(QLatin1String("/apps"))) {
                    continue;
                }
                const int value = score(info, themeDir);
                const auto existing = found.constFind(name);
                if (existing == found.constEnd() || value > existing->first) {
                    found.insert(name, {value, info.absoluteFilePath()});
                }
            }
        }
        for (auto it = found.cbegin(); it != found.cend(); ++it) {
            sources.insert(it.key(), it->second);
        }
    }
    for (const QString &name : names) {
        if (sources.contains(name)) {
            continue;
        }
        for (const QString &suffix : {QStringLiteral(".svg"), QStringLiteral(".png")}) {
            const QString path = QStandardPaths::locate(QStandardPaths::GenericDataLocation, QStringLiteral("pixmaps/") + name + suffix);
            if (!path.isEmpty()) {
                sources.insert(name, path);
                break;
            }
        }
    }
    return sources;
}

AppIcons::Palette palette(const QString &theme)
{
    static const QRegularExpression container(QStringLiteral("<circle[^>]*\\bfill=\"(#[0-9A-Fa-f]{6})\""));
    static const QRegularExpression ink(QStringLiteral("<g fill=\"(#[0-9A-Fa-f]{6})\""));
    for (const QString &name : {theme, QStringLiteral("Kernora")}) {
        for (const QString &base : systemIconBases()) {
            QFile file(base + QLatin1Char('/') + name + QStringLiteral("/scalable/apps/org.kernora.settings.svg"));
            if (!file.open(QIODevice::ReadOnly)) {
                continue;
            }
            const QString text = QString::fromUtf8(file.readAll());
            const QRegularExpressionMatch background = container.match(text);
            const QRegularExpressionMatch glyph = ink.match(text);
            if (background.hasMatch() && glyph.hasMatch()) {
                return {QColor(background.captured(1)), QColor(glyph.captured(1))};
            }
        }
    }
    return {QColor(0xff, 0xdb, 0xcc), QColor(0x37, 0x0e, 0x00)};
}

QSet<QString> applicationIcons()
{
    static const QRegularExpression suffix(QStringLiteral("\\.(png|svgz?|xpm)$"));
    const QSet<QString> provided = kernoraIcons();
    QSet<QString> names;
    const KService::List services = KService::allServices();
    for (const KService::Ptr &service : services) {
        if (!service->isApplication() || service->noDisplay()) {
            continue;
        }
        QString icon = service->icon();
        if (icon.isEmpty() || icon.startsWith(QLatin1Char('/')) || icon.startsWith(QLatin1String("org.kernora."))) {
            continue;
        }
        icon.remove(suffix);
        if (!provided.contains(icon)) {
            names.insert(icon);
        }
    }
    return names;
}
}

AppIconSync::AppIconSync()
    : m_kernorarc(QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + QStringLiteral("/kernorarc"))
    , m_kdeglobals(QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + QStringLiteral("/kdeglobals"))
{
    m_timer.setSingleShot(true);
    connect(&m_timer, &QTimer::timeout, this, [this]() {
        m_kernorarcSeen = QFileInfo(m_kernorarc).lastModified();
        m_kdeglobalsSeen = QFileInfo(m_kdeglobals).lastModified();
        syncNow();
    });
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this]() {
        if (QFileInfo(m_kernorarc).lastModified() != m_kernorarcSeen || QFileInfo(m_kdeglobals).lastModified() != m_kdeglobalsSeen) {
            schedule();
        }
    });
    m_watcher.addPath(QFileInfo(m_kernorarc).absolutePath());
    connect(KSycoca::self(), &KSycoca::databaseChanged, this, &AppIconSync::schedule);
    m_timer.start(SettleDelay * 2);
}

void AppIconSync::schedule()
{
    m_timer.start(SettleDelay);
}

bool AppIconSync::syncNow()
{
    KConfig globals(QStringLiteral("kdeglobals"));
    const QString theme = globals.group(QStringLiteral("Icons")).readEntry("Theme", QString());
    if (!theme.startsWith(QLatin1String("Kernora"))) {
        return false;
    }
    KConfig kernora(QStringLiteral("kernorarc"), KConfig::SimpleConfig);
    const bool themed = kernora.group(QStringLiteral("Icons")).readEntry("themedApps", false);
    const AppIcons::Palette colours = palette(theme);
    const QHash<QString, QString> sources = findSources(applicationIcons());

    const QString target = userIcons() + QStringLiteral("/Kernora/scalable/apps");
    const QString state = QStandardPaths::writableLocation(QStandardPaths::GenericStateLocation) + QStringLiteral("/kernora");
    QDir().mkpath(target);
    QDir().mkpath(state);
    KConfig manifestFile(state + QStringLiteral("/app-icons"), KConfig::SimpleConfig);
    KConfigGroup manifest = manifestFile.group(QStringLiteral("Icons"));

    bool changed = false;
    QSet<QString> kept;
    for (auto it = sources.cbegin(); it != sources.cend(); ++it) {
        const QString &name = it.key();
        const QString &path = it.value();
        const QString file = target + QLatin1Char('/') + name + QStringLiteral(".svg");
        const QString signature = QStringLiteral("%1|%2|%3|%4|%5|%6")
                                      .arg(QString::number(Version), path, QString::number(QFileInfo(path).lastModified().toMSecsSinceEpoch()),
                                           themed ? QStringLiteral("themed") : QStringLiteral("standard"), colours.container.name(), colours.ink.name());
        if (manifest.readEntry(name, QString()) == signature && QFileInfo::exists(file)) {
            kept.insert(name);
            continue;
        }
        const QImage icon = AppIcons::load(path);
        if (icon.isNull()) {
            continue;
        }
        QSaveFile out(file);
        if (!out.open(QIODevice::WriteOnly)) {
            continue;
        }
        out.write(AppIcons::svg(themed ? AppIcons::themed(icon, colours) : AppIcons::standard(icon)));
        if (out.commit()) {
            manifest.writeEntry(name, signature);
            kept.insert(name);
            changed = true;
        }
    }
    const QStringList listed = manifest.keyList();
    for (const QString &name : listed) {
        if (!kept.contains(name)) {
            QFile::remove(target + QLatin1Char('/') + name + QStringLiteral(".svg"));
            manifest.deleteEntry(name);
            changed = true;
        }
    }
    if (changed) {
        manifestFile.sync();
        QDBusMessage message = QDBusMessage::createSignal(QStringLiteral("/KIconLoader"), QStringLiteral("org.kde.KIconLoader"), QStringLiteral("iconChanged"));
        message << 0;
        QDBusConnection::sessionBus().send(message);
    }
    return changed;
}
