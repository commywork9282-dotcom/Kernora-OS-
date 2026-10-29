// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <QDateTime>
#include <QFileSystemWatcher>
#include <QObject>
#include <QTimer>

class AppIconSync : public QObject
{
public:
    AppIconSync();

    static bool syncNow();

private:
    void schedule();

    QString m_kernorarc;
    QString m_kdeglobals;
    QFileSystemWatcher m_watcher;
    QTimer m_timer;
    QDateTime m_kernorarcSeen;
    QDateTime m_kdeglobalsSeen;
};
