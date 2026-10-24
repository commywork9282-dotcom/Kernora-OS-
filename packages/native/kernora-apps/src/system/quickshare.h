// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <QJSValue>
#include <QObject>
#include <QUrl>
#include <QVariant>
#include <QtQml/qqmlregistration.h>

class QDBusServiceWatcher;

class QuickShare : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool available READ available NOTIFY changed)
    Q_PROPERTY(bool enabled READ enabled NOTIFY changed)
    Q_PROPERTY(QString visibility READ visibility NOTIFY changed)
    Q_PROPERTY(int visibleFor READ visibleFor NOTIFY changed)
    Q_PROPERTY(QString name READ name NOTIFY changed)
    Q_PROPERTY(QString folder READ folder NOTIFY changed)
    Q_PROPERTY(bool askNearby READ askNearby NOTIFY changed)
    Q_PROPERTY(bool discovering READ discovering NOTIFY changed)
    Q_PROPERTY(QVariantList devices READ devices NOTIFY changed)
    Q_PROPERTY(QVariantList transfers READ transfers NOTIFY changed)

public:
    explicit QuickShare(QObject *parent = nullptr);

    bool available() const { return m_available; }
    bool enabled() const { return m_state.value(QStringLiteral("enabled"), true).toBool(); }
    QString visibility() const { return m_state.value(QStringLiteral("visibility")).toString(); }
    int visibleFor() const { return m_state.value(QStringLiteral("visibleFor")).toInt(); }
    QString name() const { return m_state.value(QStringLiteral("name")).toString(); }
    QString folder() const { return m_state.value(QStringLiteral("folder")).toString(); }
    bool askNearby() const { return m_state.value(QStringLiteral("askNearby"), true).toBool(); }
    bool discovering() const { return m_state.value(QStringLiteral("discovering")).toBool(); }
    QVariantList devices() const { return m_state.value(QStringLiteral("devices")).toList(); }
    QVariantList transfers() const { return m_state.value(QStringLiteral("transfers")).toList(); }

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void setEnabled(bool enabled);
    Q_INVOKABLE void setHighVisibility(bool on);
    Q_INVOKABLE void setVisibility(const QString &mode);
    Q_INVOKABLE void setName(const QString &name);
    Q_INVOKABLE void setFolder(const QUrl &folder);
    Q_INVOKABLE void setAskNearby(bool enabled);
    Q_INVOKABLE void startDiscovery();
    Q_INVOKABLE void stopDiscovery();
    Q_INVOKABLE void send(const QString &device, const QVariantList &files, const QJSValue &callback = QJSValue());
    Q_INVOKABLE void accept(const QString &transfer);
    Q_INVOKABLE void decline(const QString &transfer);
    Q_INVOKABLE void cancel(const QString &transfer);
    Q_INVOKABLE void dismiss(const QString &transfer);

Q_SIGNALS:
    void changed();

private Q_SLOTS:
    void onChanged(const QString &state);

private:
    void apply(const QString &state);
    void call(const QString &method, const QVariantList &arguments = {});

    QVariantMap m_state;
    bool m_available = false;
    QDBusServiceWatcher *m_watcher = nullptr;
};
