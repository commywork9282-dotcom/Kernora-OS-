// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "portcontrol.h"

#include <QDir>
#include <QFile>
#include <QProcess>
#include <QTimer>
#include <QVariantMap>

#include <KLocalizedString>
#include <KNotification>

#include <algorithm>

#include <unistd.h>

namespace
{
const QString helper = QStringLiteral("/usr/libexec/kernora-terminal-ports");

QSet<int> descendants(const QList<int> &roots)
{
    QHash<int, QList<int>> children;
    const QStringList entries = QDir(QStringLiteral("/proc")).entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &entry : entries) {
        bool numeric = false;
        const int pid = entry.toInt(&numeric);
        if (!numeric) {
            continue;
        }
        QFile file(QStringLiteral("/proc/%1/stat").arg(pid));
        if (!file.open(QIODevice::ReadOnly)) {
            continue;
        }
        const QByteArray stat = file.readAll();
        const qsizetype close = stat.lastIndexOf(')');
        if (close < 0) {
            continue;
        }
        const QList<QByteArray> fields = stat.mid(close + 2).split(' ');
        if (fields.size() > 1) {
            children[fields.at(1).toInt()].append(pid);
        }
    }
    QSet<int> result;
    QList<int> queue = roots;
    while (!queue.isEmpty()) {
        const int pid = queue.takeFirst();
        if (pid <= 0 || result.contains(pid)) {
            continue;
        }
        result.insert(pid);
        queue.append(children.value(pid));
    }
    return result;
}

bool loopback(const QString &address)
{
    if (address.size() == 8) {
        return address.endsWith(QLatin1String("7F"), Qt::CaseInsensitive);
    }
    return address == QLatin1String("00000000000000000000000001000000")
        || (address.startsWith(QLatin1String("0000000000000000FFFF0000"), Qt::CaseInsensitive) && address.endsWith(QLatin1String("7F"), Qt::CaseInsensitive));
}

QHash<quint64, int> exposedListeners()
{
    QHash<quint64, int> result;
    for (const QString &table : {QStringLiteral("/proc/net/tcp"), QStringLiteral("/proc/net/tcp6")}) {
        QFile file(table);
        if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            continue;
        }
        const QList<QByteArray> lines = file.readAll().split('\n');
        for (qsizetype i = 1; i < lines.size(); ++i) {
            const QStringList fields = QString::fromLatin1(lines.at(i)).simplified().split(QLatin1Char(' '));
            if (fields.size() < 10 || fields.at(3) != QLatin1String("0A")) {
                continue;
            }
            const QStringList local = fields.at(1).split(QLatin1Char(':'));
            if (local.size() != 2 || loopback(local.at(0))) {
                continue;
            }
            bool ok = false;
            const int port = local.at(1).toInt(&ok, 16);
            const quint64 inode = fields.at(9).toULongLong();
            if (ok && inode) {
                result.insert(inode, port);
            }
        }
    }
    return result;
}

QString processName(int pid)
{
    QFile file(QStringLiteral("/proc/%1/comm").arg(pid));
    return file.open(QIODevice::ReadOnly) ? QString::fromLocal8Bit(file.readAll()).trimmed() : QString();
}
}

PortControl::PortControl(QObject *parent)
    : QObject(parent)
    , m_timer(new QTimer(this))
{
    m_timer->setInterval(2000);
    connect(m_timer, &QTimer::timeout, this, &PortControl::scan);
}

PortControl::~PortControl()
{
    release();
}

void PortControl::setShells(const QList<int> &pids)
{
    m_shells = pids;
    if (m_shells.isEmpty()) {
        m_timer->stop();
    } else if (!m_timer->isActive()) {
        m_timer->start();
        QTimer::singleShot(0, this, &PortControl::scan);
    }
}

void PortControl::setAllowed(const QList<int> &ports)
{
    m_allowed = QSet<int>(ports.begin(), ports.end());
    apply();
    Q_EMIT listeningChanged();
}

QList<int> PortControl::allowed() const
{
    QList<int> result(m_allowed.begin(), m_allowed.end());
    std::sort(result.begin(), result.end());
    return result;
}

QVariantList PortControl::listening() const
{
    QList<int> ports = m_listening.keys();
    std::sort(ports.begin(), ports.end());
    QVariantList result;
    for (const int port : ports) {
        result.append(QVariantMap{{QStringLiteral("port"), port},
                                  {QStringLiteral("process"), m_listening.value(port)},
                                  {QStringLiteral("allowed"), m_allowed.contains(port)}});
    }
    return result;
}

bool PortControl::failed() const
{
    return m_failed;
}

void PortControl::scan()
{
    const QHash<quint64, int> listeners = exposedListeners();
    QHash<int, QString> found;
    if (!listeners.isEmpty()) {
        const QSet<int> pids = descendants(m_shells);
        for (const int pid : pids) {
            const QString folder = QStringLiteral("/proc/%1/fd").arg(pid);
            const QStringList fds = QDir(folder).entryList(QDir::Files | QDir::System | QDir::NoDotAndDotDot);
            for (const QString &fd : fds) {
                char buffer[64] = {};
                const QByteArray path = QFile::encodeName(folder + QLatin1Char('/') + fd);
                const ssize_t length = ::readlink(path.constData(), buffer, sizeof(buffer) - 1);
                if (length <= 0) {
                    continue;
                }
                const QByteArray link(buffer, length);
                if (!link.startsWith("socket:[")) {
                    continue;
                }
                const quint64 inode = link.mid(8, link.size() - 9).toULongLong();
                if (const auto it = listeners.constFind(inode); it != listeners.constEnd()) {
                    found.insert(it.value(), processName(pid));
                }
            }
        }
    }
    if (found != m_listening) {
        for (auto it = found.cbegin(); it != found.cend(); ++it) {
            if (!m_listening.contains(it.key()) && !m_allowed.contains(it.key()) && !m_notified.contains(it.key())) {
                m_notified.insert(it.key());
                notify(it.key(), it.value());
            }
        }
        m_listening = found;
        Q_EMIT listeningChanged();
    }
    apply();
}

void PortControl::apply()
{
    QList<int> blocked;
    for (auto it = m_listening.cbegin(); it != m_listening.cend(); ++it) {
        if (!m_allowed.contains(it.key())) {
            blocked.append(it.key());
        }
    }
    std::sort(blocked.begin(), blocked.end());
    if (blocked == m_applied) {
        return;
    }
    if (m_helper) {
        m_pendingApply = true;
        return;
    }
    m_pending = blocked;
    m_helper = new QProcess(this);
    QStringList arguments{helper};
    for (const int port : blocked) {
        arguments.append(QString::number(port));
    }
    connect(m_helper, &QProcess::finished, this, [this](int code, QProcess::ExitStatus status) {
        const bool ok = status == QProcess::NormalExit && code == 0;
        if (ok) {
            m_applied = m_pending;
        }
        if (m_failed != !ok) {
            m_failed = !ok;
            Q_EMIT listeningChanged();
        }
        m_helper->deleteLater();
        m_helper = nullptr;
        if (m_pendingApply && ok) {
            m_pendingApply = false;
            apply();
        }
    });
    m_helper->start(QStringLiteral("pkexec"), arguments);
}

void PortControl::notify(int port, const QString &process)
{
    auto *notification = new KNotification(QStringLiteral("portRequest"));
    notification->setComponentName(QStringLiteral("kernora-terminal"));
    notification->setIconName(QStringLiteral("org.kernora.terminal"));
    notification->setTitle(i18nc("@title notification", "Terminal is requesting to open a new port"));
    notification->setText(process.isEmpty() ? i18nc("@info", "Port requested: %1", QString::number(port))
                                            : i18nc("@info", "Port requested: %1 (%2)", QString::number(port), process));
    KNotificationAction *allow = notification->addAction(i18nc("@action", "Accept"));
    notification->addAction(i18nc("@action", "Deny"));
    connect(allow, &KNotificationAction::activated, this, [this, port]() {
        Q_EMIT allowRequested(port);
    });
    notification->sendEvent();
}

void PortControl::release()
{
    m_timer->stop();
    if (m_applied.isEmpty()) {
        return;
    }
    QProcess process;
    process.start(QStringLiteral("pkexec"), {helper});
    process.waitForFinished(3000);
    m_applied.clear();
}
