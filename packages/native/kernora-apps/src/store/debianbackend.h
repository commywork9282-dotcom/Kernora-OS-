// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <QHash>
#include <QObject>
#include <QPointer>
#include <QSet>
#include <QString>
#include <QStringList>
#include <QVariantMap>

#include <functional>

namespace PackageKit
{
class Transaction;
}

class DebianBackend : public QObject
{
    Q_OBJECT

public:
    explicit DebianBackend(QObject *parent = nullptr);

    bool available() const;
    void loadInstalled();
    bool isInstalled(const QString &package) const;
    QString installedVersion(const QString &package) const;

    void refreshCache(std::function<void(bool)> done);
    void install(const QString &job, const QStringList &packages);
    void remove(const QString &job, const QStringList &packages);
    void installFile(const QString &job, const QString &path);
    void fileDetails(const QString &path, std::function<void(const QVariantMap &)> done);
    void cancel(const QString &job);

Q_SIGNALS:
    void progress(const QString &job, int percent, const QString &status);
    void finished(const QString &job, bool success, const QString &error);

private:
    void track(const QString &job, PackageKit::Transaction *transaction, const QString &failure);
    void resolve(const QString &job, const QStringList &packages, bool installed, std::function<void(const QStringList &)> done);

    QHash<QString, QString> m_installed;
    QHash<QString, QPointer<PackageKit::Transaction>> m_transactions;
};
