// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "accounts.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDir>
#include <QFileInfo>
#include <QImage>
#include <QStandardPaths>
#include <QTemporaryFile>

#include <KLocalizedString>

#include <crypt.h>
#include <pwd.h>
#include <unistd.h>

static const QString s_service = QStringLiteral("org.freedesktop.Accounts");
static const QString s_userInterface = QStringLiteral("org.freedesktop.Accounts.User");

Accounts::Accounts(QObject *parent)
    : QObject(parent)
{
    if (const passwd *pw = getpwuid(getuid())) {
        m_userName = QString::fromLocal8Bit(pw->pw_name);
        m_realName = QString::fromLocal8Bit(pw->pw_gecos).section(QLatin1Char(','), 0, 0);
    }
    QDBusMessage find = QDBusMessage::createMethodCall(s_service, QStringLiteral("/org/freedesktop/Accounts"), s_service,
                                                       QStringLiteral("FindUserById"));
    find.setArguments({static_cast<qlonglong>(getuid())});
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(find), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *self) {
        QDBusPendingReply<QDBusObjectPath> reply = *self;
        self->deleteLater();
        if (reply.isError()) {
            return;
        }
        m_path = reply.value().path();
        QDBusConnection::systemBus().connect(s_service, m_path, s_userInterface, QStringLiteral("Changed"), this,
                                             SLOT(reload()));
        reload();
    });
}

void Accounts::reload()
{
    if (m_path.isEmpty()) {
        return;
    }
    QDBusInterface user(s_service, m_path, s_userInterface, QDBusConnection::systemBus());
    const QString real = user.property("RealName").toString();
    const QString icon = user.property("IconFile").toString();
    const bool admin = user.property("AccountType").toInt() == 1;
    if (real != m_realName || icon != m_iconFile || admin != m_administrator) {
        m_realName = real;
        m_iconFile = icon;
        m_administrator = admin;
        ++m_avatarVersion;
        Q_EMIT changed();
    }
}

QUrl Accounts::avatar() const
{
    for (const QString &path : QStringList{m_iconFile, QDir::homePath() + QStringLiteral("/.face")}) {
        if (!path.isEmpty() && QFileInfo(path).isReadable() && QFileInfo(path).size() > 0) {
            QUrl url = QUrl::fromLocalFile(path);
            url.setQuery(QStringLiteral("v=%1").arg(m_avatarVersion));
            return url;
        }
    }
    return QUrl();
}

QString Accounts::initials() const
{
    const QString name = displayName().trimmed();
    return name.isEmpty() ? QStringLiteral("?") : name.left(1).toUpper();
}

void Accounts::callUser(const QString &method, const QVariantList &arguments, std::function<void()> done)
{
    if (m_path.isEmpty()) {
        Q_EMIT failed(i18n("The account service is not available."));
        return;
    }
    QDBusMessage message = QDBusMessage::createMethodCall(s_service, m_path, s_userInterface, method);
    message.setArguments(arguments);
    message.setInteractiveAuthorizationAllowed(true);
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(message, 10 * 60 * 1000), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, done](QDBusPendingCallWatcher *self) {
        QDBusPendingReply<> reply = *self;
        self->deleteLater();
        if (reply.isError()) {
            if (reply.error().type() != QDBusError::AccessDenied || !reply.error().message().contains(QLatin1String("dismissed"))) {
                Q_EMIT failed(reply.error().message());
            }
            return;
        }
        reload();
        if (done) {
            done();
        }
    });
}

void Accounts::setRealName(const QString &name)
{
    callUser(QStringLiteral("SetRealName"), {name.trimmed()});
}

void Accounts::setAvatar(const QUrl &image)
{
    QImage source(image.toLocalFile());
    if (source.isNull()) {
        Q_EMIT failed(i18n("This picture could not be read."));
        return;
    }
    const int side = std::min(source.width(), source.height());
    const QImage square = source.copy((source.width() - side) / 2, (source.height() - side) / 2, side, side)
                              .scaled(512, 512, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    const QString path = QDir::homePath() + QStringLiteral("/.face");
    if (!square.save(path, "PNG")) {
        Q_EMIT failed(i18n("The picture could not be saved."));
        return;
    }
    ++m_avatarVersion;
    Q_EMIT changed();
    callUser(QStringLiteral("SetIconFile"), {path});
}

QList<QUrl> Accounts::stockAvatars() const
{
    QList<QUrl> avatars;
    const QStringList roots = QStandardPaths::locateAll(QStandardPaths::GenericDataLocation,
                                                        QStringLiteral("plasma/avatars"), QStandardPaths::LocateDirectory);
    for (const QString &root : roots) {
        const auto entries = QDir(root).entryInfoList({QStringLiteral("*.png"), QStringLiteral("*.jpg")}, QDir::Files, QDir::Name);
        for (const QFileInfo &entry : entries) {
            avatars.append(QUrl::fromLocalFile(entry.absoluteFilePath()));
        }
    }
    return avatars;
}

void Accounts::setPassword(const QString &password)
{
    char salt[CRYPT_GENSALT_OUTPUT_SIZE];
    if (!crypt_gensalt_rn("$y$", 0, nullptr, 0, salt, sizeof(salt))) {
        Q_EMIT failed(i18n("The password could not be prepared."));
        return;
    }
    crypt_data data = {};
    const char *hash = crypt_rn(password.toUtf8().constData(), salt, &data, sizeof(data));
    if (!hash || hash[0] == '*') {
        Q_EMIT failed(i18n("The password could not be prepared."));
        return;
    }
    callUser(QStringLiteral("SetPassword"), {QString::fromLatin1(hash), QString()}, [this]() {
        Q_EMIT passwordChanged();
    });
}
