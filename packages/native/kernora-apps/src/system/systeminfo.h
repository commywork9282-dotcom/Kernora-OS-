// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <QObject>
#include <QVariant>
#include <QtQml/qqmlregistration.h>

class SystemInfo : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QString osName READ osName CONSTANT)
    Q_PROPERTY(QString osVersion READ osVersion CONSTANT)
    Q_PROPERTY(QString osPrettyName READ osPrettyName CONSTANT)
    Q_PROPERTY(QString osCodename READ osCodename CONSTANT)
    Q_PROPERTY(QString osLogo READ osLogo CONSTANT)
    Q_PROPERTY(QString osBase READ osBase CONSTANT)
    Q_PROPERTY(QString kernel READ kernel CONSTANT)
    Q_PROPERTY(QString architecture READ architecture CONSTANT)
    Q_PROPERTY(QString cpu READ cpu CONSTANT)
    Q_PROPERTY(int cpuThreads READ cpuThreads CONSTANT)
    Q_PROPERTY(qint64 memoryBytes READ memoryBytes CONSTANT)
    Q_PROPERTY(QString vendor READ vendor CONSTANT)
    Q_PROPERTY(QString product READ product CONSTANT)
    Q_PROPERTY(QString chassis READ chassis CONSTANT)
    Q_PROPERTY(QString graphics READ graphics CONSTANT)
    Q_PROPERTY(QString windowingSystem READ windowingSystem CONSTANT)
    Q_PROPERTY(QString qtVersion READ qtVersion CONSTANT)
    Q_PROPERTY(QString frameworksVersion READ frameworksVersion CONSTANT)
    Q_PROPERTY(QString plasmaVersion READ plasmaVersion CONSTANT)
    Q_PROPERTY(QString hostname READ hostname CONSTANT)
    Q_PROPERTY(bool live READ live CONSTANT)

public:
    explicit SystemInfo(QObject *parent = nullptr);

    QString osName() const { return m_os.value(QStringLiteral("NAME"), QStringLiteral("Kernora OS")); }
    QString osVersion() const { return m_os.value(QStringLiteral("VERSION")); }
    QString osPrettyName() const { return m_os.value(QStringLiteral("PRETTY_NAME"), osName()); }
    QString osCodename() const { return m_os.value(QStringLiteral("VERSION_CODENAME")); }
    QString osLogo() const { return m_os.value(QStringLiteral("LOGO"), QStringLiteral("kernora-logo")); }
    QString osBase() const;
    QString kernel() const;
    QString architecture() const;
    QString cpu() const { return m_cpu; }
    int cpuThreads() const;
    qint64 memoryBytes() const { return m_memory; }
    QString vendor() const { return dmi(QStringLiteral("sys_vendor")); }
    QString product() const;
    QString chassis() const;
    QString graphics() const;
    QString windowingSystem() const;
    QString qtVersion() const;
    QString frameworksVersion() const;
    QString plasmaVersion() const { return packageVersion(QStringLiteral("plasma-workspace")); }
    QString hostname() const;
    bool live() const;

    Q_INVOKABLE QVariantList storage() const;
    Q_INVOKABLE qint64 memoryAvailable() const;
    Q_INVOKABLE QString formatBytes(qint64 bytes) const;
    Q_INVOKABLE QString packageVersion(const QString &package) const;
    Q_INVOKABLE qint64 uptimeSeconds() const;
    Q_INVOKABLE QVariantList releaseNotes() const;

private:
    static QString dmi(const QString &name);

    QHash<QString, QString> m_os;
    QString m_cpu;
    qint64 m_memory = 0;
    mutable QString m_graphics;
};
