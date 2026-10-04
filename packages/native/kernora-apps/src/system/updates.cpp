// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "updates.h"

#include <QDateTime>
#include <QFileInfo>
#include <QLocale>

#include <KLocalizedString>

#include <PackageKit/Daemon>
#include <PackageKit/Transaction>

using PackageKit::Daemon;
using PackageKit::Transaction;

Updates::Updates(QObject *parent)
    : QObject(parent)
{
    Daemon::global()->setHints({QStringLiteral("interactive=true"),
                                QStringLiteral("locale=%1.UTF-8").arg(QLocale::system().name())});
}

bool Updates::available() const
{
    return QFileInfo::exists(QStringLiteral("/usr/libexec/packagekitd"));
}

qint64 Updates::lastCheck() const
{
    const QFileInfo stamp(QStringLiteral("/var/lib/apt/periodic/update-success-stamp"));
    const QFileInfo lists(QStringLiteral("/var/lib/apt/lists"));
    const QFileInfo &source = stamp.exists() ? stamp : lists;
    return source.exists() ? source.lastModified().toMSecsSinceEpoch() : 0;
}

void Updates::setState(State state)
{
    m_state = state;
    Q_EMIT stateChanged();
}

static QString statusText(Transaction::Status status)
{
    switch (status) {
    case Transaction::StatusDownload:
        return i18n("Downloading…");
    case Transaction::StatusInstall:
    case Transaction::StatusUpdate:
        return i18n("Installing…");
    case Transaction::StatusRefreshCache:
    case Transaction::StatusDownloadRepository:
    case Transaction::StatusDownloadPackagelist:
        return i18n("Checking for updates…");
    case Transaction::StatusWaitingForAuth:
        return i18n("Waiting for authorisation…");
    case Transaction::StatusWaitingForLock:
    case Transaction::StatusWait:
        return i18n("Waiting for another installation to finish…");
    case Transaction::StatusCleanup:
        return i18n("Finishing…");
    default:
        return i18n("Working…");
    }
}

void Updates::track(QObject *object)
{
    auto *transaction = qobject_cast<Transaction *>(object);
    connect(transaction, &Transaction::percentageChanged, this, [this, transaction]() {
        const uint percentage = transaction->percentage();
        m_progress = percentage <= 100 ? int(percentage) : m_progress;
        Q_EMIT progressChanged();
    });
    connect(transaction, &Transaction::statusChanged, this, [this, transaction]() {
        m_status = statusText(transaction->status());
        Q_EMIT progressChanged();
    });
    connect(transaction, &Transaction::errorCode, this, [this](Transaction::Error, const QString &details) {
        m_error = details;
    });
    connect(transaction, &Transaction::requireRestart, this, [this](Transaction::Restart type, const QString &) {
        if (type == Transaction::RestartSystem || type == Transaction::RestartSecuritySystem || type == Transaction::RestartSession) {
            m_restart = true;
        }
    });
}

void Updates::check()
{
    if (m_state == Checking || m_state == Installing) {
        return;
    }
    m_error.clear();
    m_progress = 0;
    m_status = i18n("Checking for updates…");
    Q_EMIT progressChanged();
    setState(Checking);
    Transaction *refresh = Daemon::refreshCache(false);
    track(refresh);
    connect(refresh, &Transaction::finished, this, [this](Transaction::Exit exit) {
        if (exit != Transaction::ExitSuccess && exit != Transaction::ExitCancelled) {
            if (m_error.isEmpty()) {
                m_error = i18n("The update sources could not be reached.");
            }
        }
        fetchUpdates();
    });
}

void Updates::fetchUpdates()
{
    m_packages.clear();
    m_ids.clear();
    Transaction *list = Daemon::getUpdates();
    track(list);
    connect(list, &Transaction::package, this, [this](Transaction::Info info, const QString &id, const QString &summary) {
        if (info == Transaction::InfoBlocked) {
            return;
        }
        m_ids.append(id);
        m_packages.append(QVariantMap{{QStringLiteral("name"), Daemon::packageName(id)},
                                      {QStringLiteral("version"), Daemon::packageVersion(id)},
                                      {QStringLiteral("summary"), summary},
                                      {QStringLiteral("security"), info == Transaction::InfoSecurity}});
    });
    connect(list, &Transaction::finished, this, [this](Transaction::Exit exit) {
        Q_EMIT packagesChanged();
        if (exit != Transaction::ExitSuccess) {
            setState(Failed);
            return;
        }
        setState(m_ids.isEmpty() ? UpToDate : UpdatesAvailable);
    });
}

void Updates::install()
{
    if (m_ids.isEmpty() || m_state == Installing) {
        return;
    }
    m_error.clear();
    m_progress = 0;
    setState(Installing);
    Transaction *update = Daemon::updatePackages(m_ids, Transaction::TransactionFlagOnlyTrusted);
    track(update);
    connect(update, &Transaction::finished, this, [this](Transaction::Exit exit) {
        if (exit == Transaction::ExitSuccess) {
            m_ids.clear();
            m_packages.clear();
            Q_EMIT packagesChanged();
            setState(Installed);
        } else if (exit == Transaction::ExitCancelled || exit == Transaction::ExitEulaRequired) {
            setState(UpdatesAvailable);
        } else {
            if (m_error.isEmpty()) {
                m_error = i18n("The updates could not be installed.");
            }
            setState(Failed);
        }
    });
}
