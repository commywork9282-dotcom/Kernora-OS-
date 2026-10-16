// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <QDateTime>
#include <QFileSystemWatcher>
#include <QObject>
#include <QPointer>
#include <QProcess>
#include <QTimer>

class GreeterSync : public QObject
{
public:
    GreeterSync();

private:
    struct Wallpaper {
        QString plugin;
        QString image;
        qint64 stamp = 0;
        QString colour;
        QString mode;
    };

    void watch();
    QString signature() const;
    void schedule();
    void sync();
    Wallpaper desktopWallpaper() const;
    bool alreadySynced(const Wallpaper &wallpaper) const;

    QString m_appletsrc;
    QFileSystemWatcher m_watcher;
    QTimer m_timer;
    QPointer<QProcess> m_process;
    QString m_seen;
    bool m_again = false;
};
