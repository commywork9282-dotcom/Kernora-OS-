// SPDX-FileCopyrightText: 2026 Lumo contributors
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <QElapsedTimer>
#include <QHash>
#include <QObject>
#include <QVariant>
#include <QtQml/qqmlregistration.h>

class Tasks : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit Tasks(QObject *parent = nullptr);

    Q_INVOKABLE QVariantMap sample();
    Q_INVOKABLE bool end(int pid, bool force = false);

private:
    struct CpuTimes {
        quint64 busy = 0;
        quint64 total = 0;
    };

    CpuTimes readCpu() const;
    QVariantList readProcesses(quint64 elapsedTicks, int threads);
    int readGpuBusy() const;
    quint64 readDiskBytes() const;
    void readNetBytes(quint64 &received, quint64 &sent) const;

    CpuTimes m_cpu;
    QHash<int, quint64> m_processTicks;
    QElapsedTimer m_clock;
    quint64 m_disk = 0;
    quint64 m_received = 0;
    quint64 m_sent = 0;
    bool m_primed = false;
};
