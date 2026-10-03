// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <QObject>
#include <QQmlParserStatus>
#include <QVariant>
#include <QtQml/qqmlregistration.h>

#include <KConfigWatcher>
#include <KSharedConfig>

class Config : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit Config(QObject *parent = nullptr);

    Q_INVOKABLE QVariant read(const QString &file, const QString &group, const QString &key,
                              const QVariant &defaultValue = QVariant()) const;
    Q_INVOKABLE void write(const QString &file, const QString &group, const QString &key,
                           const QVariant &value, bool notify = true);
    Q_INVOKABLE void remove(const QString &file, const QString &group, const QString &key);
    Q_INVOKABLE QStringList groupList(const QString &file, const QString &group = QString()) const;
    Q_INVOKABLE QStringList keyList(const QString &file, const QString &group) const;

    static KConfigGroup group(const KSharedConfig::Ptr &config, const QString &path);
    static KSharedConfig::Ptr open(const QString &file);
};

class ConfigEntry : public QObject, public QQmlParserStatus
{
    Q_OBJECT
    QML_ELEMENT
    Q_INTERFACES(QQmlParserStatus)

    Q_PROPERTY(QString file READ file WRITE setFile NOTIFY sourceChanged)
    Q_PROPERTY(QString group READ group WRITE setGroup NOTIFY sourceChanged)
    Q_PROPERTY(QString key READ key WRITE setKey NOTIFY sourceChanged)
    Q_PROPERTY(QVariant defaultValue READ defaultValue WRITE setDefaultValue NOTIFY sourceChanged)
    Q_PROPERTY(QVariant value READ value WRITE setValue NOTIFY valueChanged)
    Q_PROPERTY(bool notify READ notifyOthers WRITE setNotifyOthers NOTIFY sourceChanged)

public:
    explicit ConfigEntry(QObject *parent = nullptr);

    QString file() const { return m_file; }
    void setFile(const QString &file);
    QString group() const { return m_group; }
    void setGroup(const QString &group);
    QString key() const { return m_key; }
    void setKey(const QString &key);
    QVariant defaultValue() const { return m_default; }
    void setDefaultValue(const QVariant &value);
    QVariant value() const { return m_value; }
    void setValue(const QVariant &value);
    bool notifyOthers() const { return m_notify; }
    void setNotifyOthers(bool notify);

    Q_INVOKABLE void reset();

    void classBegin() override { }
    void componentComplete() override;

Q_SIGNALS:
    void sourceChanged();
    void valueChanged();

private:
    void reload();
    void watch();

    QString m_file;
    QString m_group;
    QString m_key;
    QVariant m_default;
    QVariant m_value;
    bool m_notify = true;
    bool m_complete = false;
    KSharedConfig::Ptr m_config;
    KConfigWatcher::Ptr m_watcher;
};
