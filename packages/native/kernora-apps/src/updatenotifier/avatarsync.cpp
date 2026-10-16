// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "avatarsync.h"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>
#include <QSaveFile>
#include <QStandardPaths>

#include <KConfig>
#include <KConfigGroup>
#include <KUser>

static constexpr int SettleDelay = 3000;

static QByteArray readAll(const QString &path)
{
    QFile file(path);
    return file.open(QIODevice::ReadOnly) ? file.readAll() : QByteArray();
}

static QStringList stockFaces()
{
    QStringList paths{QStringLiteral("/etc/skel/.face")};
    const QString stock = QStandardPaths::locate(QStandardPaths::GenericDataLocation, QStringLiteral("kernora/avatars/00-kernora.png"));
    if (!stock.isEmpty()) {
        paths.append(stock);
    }
    const QString faces = QStandardPaths::locate(QStandardPaths::GenericDataLocation, QStringLiteral("kernora/faces"), QStandardPaths::LocateDirectory);
    if (!faces.isEmpty()) {
        for (const QFileInfo &info : QDir(faces).entryInfoList({QStringLiteral("*.png")}, QDir::Files)) {
            paths.append(info.absoluteFilePath());
        }
    }
    return paths;
}

AvatarSync::AvatarSync()
    : m_kernorarc(QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + QStringLiteral("/kernorarc"))
{
    m_timer.setSingleShot(true);
    connect(&m_timer, &QTimer::timeout, this, &AvatarSync::sync);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this]() {
        if (QFileInfo(m_kernorarc).lastModified() != m_seen) {
            schedule();
        }
    });
    m_watcher.addPath(QFileInfo(m_kernorarc).absolutePath());
    m_timer.start(SettleDelay * 2);
}

void AvatarSync::schedule()
{
    m_timer.start(SettleDelay);
}

void AvatarSync::sync()
{
    m_seen = QFileInfo(m_kernorarc).lastModified();
    KConfig config(m_kernorarc, KConfig::SimpleConfig);
    const QString colour = config.group(QStringLiteral("Style")).readEntry("colour", QStringLiteral("kernora"));
    static const QRegularExpression valid(QStringLiteral("^[a-z]+(-[a-z]+)*$"));
    if (!valid.match(colour).hasMatch()) {
        return;
    }
    const QString themed = QStandardPaths::locate(QStandardPaths::GenericDataLocation, QStringLiteral("kernora/faces/%1.png").arg(colour));
    const QString face = QDir::homePath() + QStringLiteral("/.face");
    if (themed.isEmpty() || !QFileInfo(face).isFile()) {
        return;
    }
    const QByteArray current = readAll(face);
    const QByteArray wanted = readAll(themed);
    if (current.isEmpty() || wanted.isEmpty() || current == wanted) {
        return;
    }
    bool stock = false;
    for (const QString &path : stockFaces()) {
        if (readAll(path) == current) {
            stock = true;
            break;
        }
    }
    if (!stock) {
        return;
    }
    QSaveFile out(face);
    if (!out.open(QIODevice::WriteOnly) || out.write(wanted) != wanted.size() || !out.commit()) {
        return;
    }
    publish(face);
}

void AvatarSync::publish(const QString &face)
{
    const QString service = QStringLiteral("org.freedesktop.Accounts");
    QDBusMessage find = QDBusMessage::createMethodCall(service, QStringLiteral("/org/freedesktop/Accounts"), service, QStringLiteral("FindUserByName"));
    find.setArguments({KUser().loginName()});
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(find), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [face, service](QDBusPendingCallWatcher *self) {
        QDBusPendingReply<QDBusObjectPath> reply = *self;
        self->deleteLater();
        if (reply.isError()) {
            return;
        }
        QDBusMessage set = QDBusMessage::createMethodCall(service, reply.value().path(), QStringLiteral("org.freedesktop.Accounts.User"), QStringLiteral("SetIconFile"));
        set.setArguments({face});
        QDBusConnection::systemBus().asyncCall(set);
    });
}
