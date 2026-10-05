// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "config.h"

#include <KConfigGroup>

Config::Config(QObject *parent)
    : QObject(parent)
{
}

KSharedConfig::Ptr Config::open(const QString &file)
{
    return KSharedConfig::openConfig(file);
}

KConfigGroup Config::group(const KSharedConfig::Ptr &config, const QString &path)
{
    QStringList parts;
    QString part;
    for (int i = 0; i < path.size(); ++i) {
        if (path.at(i) == QLatin1Char('\\') && i + 1 < path.size() && path.at(i + 1) == QLatin1Char('/')) {
            part.append(QLatin1Char('/'));
            ++i;
        } else if (path.at(i) == QLatin1Char('/')) {
            if (!part.isEmpty()) {
                parts.append(part);
            }
            part.clear();
        } else {
            part.append(path.at(i));
        }
    }
    if (!part.isEmpty()) {
        parts.append(part);
    }
    if (parts.isEmpty()) {
        return config->group(QString());
    }
    KConfigGroup group = config->group(parts.first());
    for (int i = 1; i < parts.size(); ++i) {
        group = group.group(parts.at(i));
    }
    return group;
}

QVariant Config::read(const QString &file, const QString &groupPath, const QString &key, const QVariant &defaultValue) const
{
    auto config = open(file);
    config->reparseConfiguration();
    const KConfigGroup g = group(config, groupPath);
    if (!g.hasKey(key)) {
        return defaultValue;
    }
    if (!defaultValue.isValid()) {
        return g.readEntry(key, QString());
    }
    return g.readEntry(key, defaultValue);
}

void Config::write(const QString &file, const QString &groupPath, const QString &key, const QVariant &value, bool notify)
{
    auto config = open(file);
    KConfigGroup g = group(config, groupPath);
    KConfig::WriteConfigFlags flags = KConfig::Persistent;
    if (notify) {
        flags |= KConfig::Notify;
    }
    g.writeEntry(key, value, flags);
    config->sync();
}

void Config::remove(const QString &file, const QString &groupPath, const QString &key)
{
    auto config = open(file);
    KConfigGroup g = group(config, groupPath);
    g.deleteEntry(key, KConfig::Persistent | KConfig::Notify);
    config->sync();
}

QStringList Config::groupList(const QString &file, const QString &groupPath) const
{
    auto config = open(file);
    config->reparseConfiguration();
    if (groupPath.isEmpty()) {
        return config->groupList();
    }
    return group(config, groupPath).groupList();
}

QStringList Config::keyList(const QString &file, const QString &groupPath) const
{
    auto config = open(file);
    config->reparseConfiguration();
    return group(config, groupPath).keyList();
}

ConfigEntry::ConfigEntry(QObject *parent)
    : QObject(parent)
{
}

void ConfigEntry::setFile(const QString &file)
{
    if (m_file == file) {
        return;
    }
    m_file = file;
    Q_EMIT sourceChanged();
    watch();
    reload();
}

void ConfigEntry::setGroup(const QString &group)
{
    if (m_group == group) {
        return;
    }
    m_group = group;
    Q_EMIT sourceChanged();
    reload();
}

void ConfigEntry::setKey(const QString &key)
{
    if (m_key == key) {
        return;
    }
    m_key = key;
    Q_EMIT sourceChanged();
    reload();
}

void ConfigEntry::setDefaultValue(const QVariant &value)
{
    if (m_default == value) {
        return;
    }
    m_default = value;
    Q_EMIT sourceChanged();
    reload();
}

void ConfigEntry::setNotifyOthers(bool notify)
{
    if (m_notify == notify) {
        return;
    }
    m_notify = notify;
    Q_EMIT sourceChanged();
}

void ConfigEntry::setValue(const QVariant &value)
{
    if (!m_config || m_key.isEmpty()) {
        m_value = value;
        Q_EMIT valueChanged();
        return;
    }
    QVariant typed = value;
    if (m_default.isValid() && typed.metaType() != m_default.metaType() && typed.canConvert(m_default.metaType())) {
        typed.convert(m_default.metaType());
    }
    if (typed == m_value) {
        return;
    }
    KConfigGroup g = Config::group(m_config, m_group);
    KConfig::WriteConfigFlags flags = KConfig::Persistent;
    if (m_notify) {
        flags |= KConfig::Notify;
    }
    g.writeEntry(m_key, typed, flags);
    m_config->sync();
    m_value = typed;
    Q_EMIT valueChanged();
}

void ConfigEntry::reset()
{
    if (!m_config || m_key.isEmpty()) {
        return;
    }
    KConfigGroup g = Config::group(m_config, m_group);
    g.revertToDefault(m_key, m_notify ? KConfig::Persistent | KConfig::Notify : KConfig::Persistent);
    m_config->sync();
    reload();
}

void ConfigEntry::componentComplete()
{
    m_complete = true;
    watch();
    reload();
}

void ConfigEntry::watch()
{
    if (!m_complete || m_file.isEmpty()) {
        return;
    }
    m_config = Config::open(m_file);
    m_watcher = KConfigWatcher::create(m_config);
    connect(m_watcher.data(), &KConfigWatcher::configChanged, this, [this](const KConfigGroup &, const QByteArrayList &) {
        m_config->reparseConfiguration();
        reload();
    });
}

void ConfigEntry::reload()
{
    if (!m_complete || !m_config || m_key.isEmpty()) {
        return;
    }
    const KConfigGroup g = Config::group(m_config, m_group);
    QVariant fresh = m_default.isValid() ? g.readEntry(m_key, m_default) : QVariant(g.readEntry(m_key, QString()));
    if (fresh != m_value) {
        m_value = fresh;
        Q_EMIT valueChanged();
    }
}
