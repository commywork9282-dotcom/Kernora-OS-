// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <QHash>
#include <QList>
#include <QObject>
#include <QSet>
#include <QVariantList>

class QProcess;
class QTimer;

class PortControl : public QObject
{
    Q_OBJECT

public:
    explicit PortControl(QObject *parent = nullptr);
    ~PortControl() override;

    void setShells(const QList<int> &pids);
    void setAllowed(const QList<int> &ports);
    QList<int> allowed() const;
    QVariantList listening() const;
    bool failed() const;
    void release();

Q_SIGNALS:
    void listeningChanged();
    void allowRequested(int port);

private:
    void scan();
    void apply();
    void notify(int port, const QString &process);

    QTimer *m_timer;
    QProcess *m_helper = nullptr;
    QList<int> m_shells;
    QSet<int> m_allowed;
    QHash<int, QString> m_listening;
    QSet<int> m_notified;
    QList<int> m_applied;
    QList<int> m_pending;
    bool m_pendingApply = false;
    bool m_failed = false;
};
