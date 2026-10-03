// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <QObject>

#include <functional>
#include <QUrl>
#include <QtQml/qqmlregistration.h>

class Accounts : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QString userName READ userName CONSTANT)
    Q_PROPERTY(QString realName READ realName NOTIFY changed)
    Q_PROPERTY(QString displayName READ displayName NOTIFY changed)
    Q_PROPERTY(QUrl avatar READ avatar NOTIFY changed)
    Q_PROPERTY(bool administrator READ administrator NOTIFY changed)
    Q_PROPERTY(QString initials READ initials NOTIFY changed)

public:
    explicit Accounts(QObject *parent = nullptr);

    QString userName() const { return m_userName; }
    QString realName() const { return m_realName; }
    QString displayName() const { return m_realName.isEmpty() ? m_userName : m_realName; }
    QUrl avatar() const;
    bool administrator() const { return m_administrator; }
    QString initials() const;

    Q_INVOKABLE void setRealName(const QString &name);
    Q_INVOKABLE void setAvatar(const QUrl &image);
    Q_INVOKABLE QList<QUrl> stockAvatars() const;
    Q_INVOKABLE void setPassword(const QString &password);

Q_SIGNALS:
    void changed();
    void failed(const QString &message);
    void passwordChanged();

private:
    Q_SLOT void reload();
    void callUser(const QString &method, const QVariantList &arguments, std::function<void()> done = {});

    QString m_path;
    QString m_userName;
    QString m_realName;
    QString m_iconFile;
    bool m_administrator = false;
    int m_avatarVersion = 0;
};
