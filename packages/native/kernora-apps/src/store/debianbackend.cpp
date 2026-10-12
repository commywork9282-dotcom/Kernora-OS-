// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "debianbackend.h"

#include <QFile>
#include <QFileInfo>
#include <QLocale>

#include <KLocalizedString>

#include <PackageKit/Daemon>
#include <PackageKit/Details>
#include <PackageKit/Transaction>

using PackageKit::Daemon;
using PackageKit::Transaction;

static QString statusText(Transaction::Status status, bool removing)
{
    switch (status) {
    case Transaction::StatusDownload:
        return i18n("Downloading…");
    case Transaction::StatusWaitingForAuth:
        return i18n("Waiting for your password…");
    case Transaction::StatusWaitingForLock:
    case Transaction::StatusWait:
        return i18n("Waiting for another installation to finish…");
    case Transaction::StatusRemove:
        return i18n("Removing…");
    default:
        return removing ? i18n("Removing…") : i18n("Installing…");
    }
}

DebianBackend::DebianBackend(QObject *parent)
    : QObject(parent)
{
    Daemon::global()->setHints({QStringLiteral("interactive=true"),
                                QStringLiteral("locale=%1.UTF-8").arg(QLocale::system().name())});
}

bool DebianBackend::available() const
{
    return QFileInfo::exists(QStringLiteral("/usr/libexec/packagekitd"));
}

void DebianBackend::loadInstalled()
{
    m_installed.clear();
    QFile status(QStringLiteral("/var/lib/dpkg/status"));
    if (!status.open(QIODevice::ReadOnly)) {
        return;
    }
    QString package;
    QString version;
    bool installed = false;
    auto flush = [&]() {
        if (installed && !package.isEmpty()) {
            m_installed.insert(package, version);
        }
        package.clear();
        version.clear();
        installed = false;
    };
    while (!status.atEnd()) {
        const QByteArray line = status.readLine().trimmed();
        if (line.isEmpty()) {
            flush();
        } else if (line.startsWith("Package: ")) {
            package = QString::fromUtf8(line.mid(9));
        } else if (line.startsWith("Version: ")) {
            version = QString::fromUtf8(line.mid(9));
        } else if (line.startsWith("Status: ")) {
            installed = line.endsWith(" ok installed");
        }
    }
    flush();
}

bool DebianBackend::isInstalled(const QString &package) const
{
    return m_installed.contains(package);
}

QString DebianBackend::installedVersion(const QString &package) const
{
    return m_installed.value(package);
}

void DebianBackend::refreshCache(std::function<void(bool)> done)
{
    if (!available()) {
        done(false);
        return;
    }
    Transaction *refresh = Daemon::refreshCache(false);
    connect(refresh, &Transaction::finished, this, [done](Transaction::Exit exit) {
        done(exit == Transaction::ExitSuccess);
    });
}

void DebianBackend::track(const QString &job, Transaction *transaction, const QString &failure)
{
    m_transactions.insert(job, transaction);
    auto error = std::make_shared<QString>();
    const bool removing = transaction->role() == Transaction::RoleRemovePackages;
    connect(transaction, &Transaction::percentageChanged, this, [this, job, transaction]() {
        const uint percentage = transaction->percentage();
        if (percentage <= 100) {
            Q_EMIT progress(job, int(percentage), statusText(transaction->status(), transaction->role() == Transaction::RoleRemovePackages));
        }
    });
    connect(transaction, &Transaction::statusChanged, this, [this, job, transaction, removing]() {
        const uint percentage = transaction->percentage();
        Q_EMIT progress(job, percentage <= 100 ? int(percentage) : -1, statusText(transaction->status(), removing));
    });
    connect(transaction, &Transaction::errorCode, this, [error](Transaction::Error code, const QString &details) {
        if (code != Transaction::ErrorTransactionCancelled && code != Transaction::ErrorNotAuthorized) {
            *error = details;
        }
    });
    connect(transaction, &Transaction::finished, this, [this, job, error, failure](Transaction::Exit exit) {
        m_transactions.remove(job);
        loadInstalled();
        if (exit == Transaction::ExitSuccess) {
            Q_EMIT finished(job, true, QString());
        } else if (exit == Transaction::ExitCancelled || exit == Transaction::ExitCancelledPriority) {
            Q_EMIT finished(job, false, QString());
        } else {
            Q_EMIT finished(job, false, error->isEmpty() ? failure : *error);
        }
    });
}

void DebianBackend::resolve(const QString &job, const QStringList &packages, bool installed, std::function<void(const QStringList &)> done)
{
    Transaction::Filters filters = Transaction::FilterArch | Transaction::FilterNewest;
    filters |= installed ? Transaction::FilterInstalled : Transaction::FilterNotInstalled;
    Transaction *lookup = Daemon::resolve(packages, filters);
    m_transactions.insert(job, lookup);
    auto ids = std::make_shared<QStringList>();
    connect(lookup, &Transaction::package, this, [ids](Transaction::Info, const QString &id, const QString &) {
        ids->append(id);
    });
    connect(lookup, &Transaction::finished, this, [this, job, ids, done](Transaction::Exit exit) {
        m_transactions.remove(job);
        if (exit == Transaction::ExitCancelled || exit == Transaction::ExitCancelledPriority) {
            Q_EMIT finished(job, false, QString());
            return;
        }
        if (exit != Transaction::ExitSuccess) {
            Q_EMIT finished(job, false, i18n("The package sources could not be read. Refresh the catalogue and try again."));
            return;
        }
        done(*ids);
    });
}

void DebianBackend::install(const QString &job, const QStringList &packages)
{
    Q_EMIT progress(job, -1, i18n("Preparing…"));
    resolve(job, packages, false, [this, job](const QStringList &ids) {
        if (ids.isEmpty()) {
            loadInstalled();
            Q_EMIT finished(job, false, i18n("This app is not available from the Debian sources right now."));
            return;
        }
        track(job, Daemon::installPackages(ids), i18n("The app could not be installed."));
    });
}

void DebianBackend::remove(const QString &job, const QStringList &packages)
{
    Q_EMIT progress(job, -1, i18n("Preparing…"));
    resolve(job, packages, true, [this, job](const QStringList &ids) {
        if (ids.isEmpty()) {
            loadInstalled();
            Q_EMIT finished(job, true, QString());
            return;
        }
        track(job, Daemon::removePackages(ids, false, true), i18n("The app could not be removed."));
    });
}

void DebianBackend::installFile(const QString &job, const QString &path)
{
    Q_EMIT progress(job, -1, i18n("Preparing…"));
    track(job, Daemon::installFiles({path}, Transaction::TransactionFlagNone), i18n("The package could not be installed."));
}

void DebianBackend::fileDetails(const QString &path, std::function<void(const QVariantMap &)> done)
{
    Transaction *lookup = Daemon::getDetailsLocal(path);
    auto values = std::make_shared<QVariantMap>();
    connect(lookup, &Transaction::details, this, [values](const PackageKit::Details &details) {
        values->insert(QStringLiteral("package"), Daemon::packageName(details.packageId()));
        values->insert(QStringLiteral("version"), Daemon::packageVersion(details.packageId()));
        values->insert(QStringLiteral("summary"), details.summary());
        values->insert(QStringLiteral("description"), details.description());
        values->insert(QStringLiteral("license"), details.license());
        values->insert(QStringLiteral("homepage"), details.url());
        values->insert(QStringLiteral("size"), double(details.size()));
    });
    connect(lookup, &Transaction::finished, this, [values, done]() {
        done(*values);
    });
}

void DebianBackend::cancel(const QString &job)
{
    const QPointer<Transaction> transaction = m_transactions.value(job);
    if (transaction) {
        transaction->cancel();
    }
}
