// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "greetersync.h"

#include <QFileInfo>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QUrl>

#include <KConfig>
#include <KConfigGroup>
#include <KSharedConfig>

#include <grp.h>
#include <unistd.h>

#include <algorithm>
#include <vector>

static const QString GreeterSettings = QStringLiteral("/usr/share/sddm/themes/kernora/theme.conf.user");
static const QString GreeterHelper = QStringLiteral("/usr/libexec/kernora-greeter-background");
static constexpr int SettleDelay = 4000;

static bool administrator()
{
    const struct group *sudo = getgrnam("sudo");
    if (!sudo) {
        return false;
    }
    const int count = getgroups(0, nullptr);
    if (count <= 0) {
        return false;
    }
    std::vector<gid_t> groups(count);
    if (getgroups(count, groups.data()) < 0) {
        return false;
    }
    return std::find(groups.cbegin(), groups.cend(), sudo->gr_gid) != groups.cend();
}

GreeterSync::GreeterSync()
    : m_appletsrc(QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + QStringLiteral("/plasma-org.kde.plasma.desktop-appletsrc"))
{
    m_timer.setSingleShot(true);
    connect(&m_timer, &QTimer::timeout, this, &GreeterSync::sync);
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, &GreeterSync::schedule);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this]() {
        const QDateTime modified = QFileInfo(m_appletsrc).lastModified();
        if (modified != m_seen) {
            schedule();
        }
    });
    m_watcher.addPath(QFileInfo(m_appletsrc).absolutePath());
    watch();
    m_timer.start(SettleDelay * 3);
}

void GreeterSync::watch()
{
    if (QFileInfo::exists(m_appletsrc) && !m_watcher.files().contains(m_appletsrc)) {
        m_watcher.addPath(m_appletsrc);
    }
}

void GreeterSync::schedule()
{
    watch();
    m_timer.start(SettleDelay);
}

GreeterSync::Wallpaper GreeterSync::desktopWallpaper() const
{
    KConfig config(m_appletsrc, KConfig::SimpleConfig);
    const KConfigGroup containments = config.group(QStringLiteral("Containments"));
    QStringList ids = containments.groupList();
    std::sort(ids.begin(), ids.end(), [](const QString &a, const QString &b) {
        return a.toInt() < b.toInt();
    });
    Wallpaper first;
    Wallpaper primary;
    for (const QString &id : std::as_const(ids)) {
        const KConfigGroup containment = containments.group(id);
        const QString type = containment.readEntry("plugin");
        Wallpaper candidate;
        candidate.plugin = containment.readEntry("wallpaperplugin");
        if (candidate.plugin.isEmpty() || (type != QLatin1String("org.kde.desktopcontainment") && type != QLatin1String("org.kde.plasma.folder"))) {
            continue;
        }
        if (candidate.plugin == QLatin1String("org.kde.image")) {
            const QString image = containment.group(QStringLiteral("Wallpaper")).group(QStringLiteral("org.kde.image")).group(QStringLiteral("General")).readEntry("Image");
            const QUrl url(image);
            candidate.image = url.isLocalFile() ? url.toLocalFile() : image;
        }
        if (first.plugin.isEmpty()) {
            first = candidate;
        }
        if (primary.plugin.isEmpty() && containment.readEntry("lastScreen", -1) == 0) {
            primary = candidate;
        }
    }
    Wallpaper found = primary.plugin.isEmpty() ? first : primary;
    if (found.plugin == QLatin1String("org.kde.image")) {
        const QFileInfo picture(found.image);
        if (found.image.isEmpty() || !picture.isFile()) {
            return {};
        }
        found.stamp = picture.lastModified().toSecsSinceEpoch();
        return found;
    }
    static const QRegularExpression live(QStringLiteral("^org\\.kernora\\.[a-z]+$"));
    if (!live.match(found.plugin).hasMatch()) {
        return {};
    }
    return found;
}

bool GreeterSync::alreadySynced(const Wallpaper &wallpaper) const
{
    KConfig greeter(GreeterSettings, KConfig::SimpleConfig);
    const KConfigGroup general = greeter.group(QStringLiteral("General"));
    if (general.readEntry("wallpaper") != wallpaper.plugin) {
        return false;
    }
    if (wallpaper.plugin == QLatin1String("org.kde.image") && general.readEntry("wallpaperImage").isEmpty()) {
        return false;
    }
    const KConfigGroup state = KSharedConfig::openStateConfig()->group(QStringLiteral("Greeter"));
    return state.readEntry("plugin") == wallpaper.plugin && state.readEntry("image") == wallpaper.image
        && state.readEntry("stamp", qint64(0)) == wallpaper.stamp;
}

void GreeterSync::sync()
{
    m_seen = QFileInfo(m_appletsrc).lastModified();
    if (m_process) {
        m_again = true;
        return;
    }
    const Wallpaper wallpaper = desktopWallpaper();
    if (wallpaper.plugin.isEmpty() || alreadySynced(wallpaper) || !administrator() || !QFileInfo::exists(GreeterHelper)) {
        return;
    }
    QStringList arguments{GreeterHelper, wallpaper.plugin};
    if (!wallpaper.image.isEmpty()) {
        arguments.append(wallpaper.image);
    }
    QProcess *process = new QProcess(this);
    m_process = process;
    connect(process, &QProcess::finished, this, [this, process, wallpaper](int code, QProcess::ExitStatus status) {
        if (status == QProcess::NormalExit && code == 0) {
            KConfigGroup state = KSharedConfig::openStateConfig()->group(QStringLiteral("Greeter"));
            state.writeEntry("plugin", wallpaper.plugin);
            state.writeEntry("image", wallpaper.image);
            state.writeEntry("stamp", wallpaper.stamp);
            state.sync();
        }
        process->deleteLater();
        m_process = nullptr;
        if (m_again) {
            m_again = false;
            schedule();
        }
    });
    process->start(QStringLiteral("pkexec"), arguments);
}
