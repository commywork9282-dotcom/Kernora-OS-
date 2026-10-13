// SPDX-FileCopyrightText: 2026 Lumo contributors
// SPDX-License-Identifier: GPL-2.0-or-later

#include "tasks.h"

#include <QDir>
#include <QFile>
#include <QRegularExpression>

#include <csignal>
#include <sys/types.h>
#include <unistd.h>

static QByteArray readAll(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        return QByteArray();
    }
    return file.readAll();
}

Tasks::Tasks(QObject *parent)
    : QObject(parent)
{
}

Tasks::CpuTimes Tasks::readCpu() const
{
    CpuTimes times;
    const QByteArray stat = readAll(QStringLiteral("/proc/stat"));
    const QList<QByteArray> fields = stat.left(stat.indexOf('\n')).simplified().split(' ');
    for (int i = 1; i < fields.size(); ++i) {
        const quint64 value = fields.at(i).toULongLong();
        times.total += value;
        if (i != 4 && i != 5) {
            times.busy += value;
        }
    }
    return times;
}

QVariantList Tasks::readProcesses(quint64 elapsedTicks, int threads)
{
    QVariantList result;
    QHash<int, quint64> ticks;
    const uid_t self = getuid();
    const long pageSize = sysconf(_SC_PAGESIZE);
    const QStringList entries = QDir(QStringLiteral("/proc")).entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &entry : entries) {
        bool ok = false;
        const int pid = entry.toInt(&ok);
        if (!ok) {
            continue;
        }
        const QString base = QStringLiteral("/proc/") + entry;
        const QByteArray stat = readAll(base + QStringLiteral("/stat"));
        const int close = stat.lastIndexOf(')');
        if (close < 0) {
            continue;
        }
        const QList<QByteArray> fields = stat.mid(close + 2).split(' ');
        if (fields.size() < 22) {
            continue;
        }
        const quint64 used = fields.at(11).toULongLong() + fields.at(12).toULongLong();
        const qint64 rss = fields.at(21).toLongLong() * pageSize;
        ticks.insert(pid, used);
        if (rss <= 0) {
            continue;
        }

        uid_t owner = 0;
        const QByteArray status = readAll(base + QStringLiteral("/status"));
        const int uidAt = status.indexOf("\nUid:");
        if (uidAt >= 0) {
            owner = status.mid(uidAt + 5, status.indexOf('\n', uidAt + 1) - uidAt - 5).simplified().split(' ').value(0).toUInt();
        }

        QString name = QString::fromUtf8(stat.mid(stat.indexOf('(') + 1, close - stat.indexOf('(') - 1));
        QByteArray command = readAll(base + QStringLiteral("/cmdline"));
        const QString program = QString::fromUtf8(command.left(command.indexOf('\0')));
        if (!program.isEmpty()) {
            const QString file = program.section(QLatin1Char('/'), -1);
            if (file.startsWith(name) || name.size() >= 15) {
                name = file;
            }
        }
        command.replace('\0', ' ');

        double cpu = 0;
        if (m_primed && elapsedTicks > 0) {
            const quint64 before = m_processTicks.value(pid, used);
            cpu = qMin(100.0, 100.0 * double(used - qMin(used, before)) / (double(elapsedTicks) * threads));
        }

        QVariantMap process;
        process.insert(QStringLiteral("pid"), pid);
        process.insert(QStringLiteral("name"), name);
        process.insert(QStringLiteral("command"), QString::fromUtf8(command.trimmed()));
        process.insert(QStringLiteral("cpu"), cpu);
        process.insert(QStringLiteral("memory"), rss);
        process.insert(QStringLiteral("mine"), owner == self);
        result.append(process);
    }
    m_processTicks = ticks;
    return result;
}

int Tasks::readGpuBusy() const
{
    const QStringList cards = QDir(QStringLiteral("/sys/class/drm")).entryList({QStringLiteral("card?")}, QDir::Dirs | QDir::System);
    int best = -1;
    for (const QString &card : cards) {
        const QByteArray value = readAll(QStringLiteral("/sys/class/drm/%1/device/gpu_busy_percent").arg(card)).trimmed();
        bool ok = false;
        const int busy = value.toInt(&ok);
        if (ok) {
            best = qMax(best, busy);
        }
    }
    return best;
}

quint64 Tasks::readDiskBytes() const
{
    quint64 sectors = 0;
    static const QRegularExpression whole(QStringLiteral("^(sd[a-z]+|nvme\\d+n\\d+|vd[a-z]+|mmcblk\\d+)$"));
    const QList<QByteArray> lines = readAll(QStringLiteral("/proc/diskstats")).split('\n');
    for (const QByteArray &line : lines) {
        const QList<QByteArray> fields = line.simplified().split(' ');
        if (fields.size() < 10 || !whole.match(QString::fromLatin1(fields.at(2))).hasMatch()) {
            continue;
        }
        sectors += fields.at(5).toULongLong() + fields.at(9).toULongLong();
    }
    return sectors * 512;
}

void Tasks::readNetBytes(quint64 &received, quint64 &sent) const
{
    received = 0;
    sent = 0;
    const QList<QByteArray> lines = readAll(QStringLiteral("/proc/net/dev")).split('\n');
    for (const QByteArray &line : lines) {
        const int colon = line.indexOf(':');
        if (colon < 0 || line.left(colon).trimmed() == "lo") {
            continue;
        }
        const QList<QByteArray> fields = line.mid(colon + 1).simplified().split(' ');
        if (fields.size() < 9) {
            continue;
        }
        received += fields.at(0).toULongLong();
        sent += fields.at(8).toULongLong();
    }
}

QVariantMap Tasks::sample()
{
    const qint64 elapsedMs = m_clock.isValid() ? qMax<qint64>(1, m_clock.restart()) : 0;
    if (!m_clock.isValid()) {
        m_clock.start();
    }
    const double seconds = elapsedMs / 1000.0;
    const int threads = qMax(1, int(sysconf(_SC_NPROCESSORS_ONLN)));

    const CpuTimes cpu = readCpu();
    const quint64 totalDelta = cpu.total - qMin(cpu.total, m_cpu.total);
    const quint64 busyDelta = cpu.busy - qMin(cpu.busy, m_cpu.busy);
    const double cpuPercent = m_primed && totalDelta > 0 ? 100.0 * double(busyDelta) / double(totalDelta) : 0;

    QVariantList processes = readProcesses(totalDelta / quint64(threads), threads);

    qint64 memTotal = 0;
    qint64 memAvailable = 0;
    qint64 swapTotal = 0;
    qint64 swapFree = 0;
    const QList<QByteArray> lines = readAll(QStringLiteral("/proc/meminfo")).split('\n');
    for (const QByteArray &line : lines) {
        const QList<QByteArray> fields = line.simplified().split(' ');
        if (fields.size() < 2) {
            continue;
        }
        const qint64 bytes = fields.at(1).toLongLong() * 1024;
        if (fields.at(0) == "MemTotal:") {
            memTotal = bytes;
        } else if (fields.at(0) == "MemAvailable:") {
            memAvailable = bytes;
        } else if (fields.at(0) == "SwapTotal:") {
            swapTotal = bytes;
        } else if (fields.at(0) == "SwapFree:") {
            swapFree = bytes;
        }
    }

    const quint64 disk = readDiskBytes();
    quint64 received = 0;
    quint64 sent = 0;
    readNetBytes(received, sent);
    const auto rate = [this, seconds](quint64 now, quint64 before) {
        return m_primed && seconds > 0 ? double(now - qMin(now, before)) / seconds : 0.0;
    };

    QVariantMap result;
    result.insert(QStringLiteral("cpu"), cpuPercent);
    result.insert(QStringLiteral("threads"), threads);
    result.insert(QStringLiteral("memoryTotal"), memTotal);
    result.insert(QStringLiteral("memoryUsed"), memTotal - memAvailable);
    result.insert(QStringLiteral("swapTotal"), swapTotal);
    result.insert(QStringLiteral("swapUsed"), swapTotal - swapFree);
    result.insert(QStringLiteral("gpu"), readGpuBusy());
    result.insert(QStringLiteral("disk"), rate(disk, m_disk));
    result.insert(QStringLiteral("received"), rate(received, m_received));
    result.insert(QStringLiteral("sent"), rate(sent, m_sent));
    result.insert(QStringLiteral("processes"), processes);

    m_cpu = cpu;
    m_disk = disk;
    m_received = received;
    m_sent = sent;
    m_primed = true;
    return result;
}

bool Tasks::end(int pid, bool force)
{
    if (pid <= 1 || pid == getpid()) {
        return false;
    }
    return ::kill(pid, force ? SIGKILL : SIGTERM) == 0;
}
