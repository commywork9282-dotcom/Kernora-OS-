// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QObject>
#include <QPointer>
#include <QVariantMap>

#include "types.h"

class QQmlComponent;
class QQmlEngine;

class FileChooser : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.impl.portal.FileChooser")
    Q_PROPERTY(uint version READ version CONSTANT)

public:
    explicit FileChooser(QQmlEngine *engine, QObject *parent = nullptr);

    uint version() const
    {
        return 4;
    }
    int pending() const
    {
        return m_pending;
    }

Q_SIGNALS:
    void idle();

public Q_SLOTS:
    uint OpenFile(const QDBusObjectPath &handle, const QString &app_id, const QString &parent_window, const QString &title,
                  const QVariantMap &options, const QDBusMessage &message, QVariantMap &results);
    uint SaveFile(const QDBusObjectPath &handle, const QString &app_id, const QString &parent_window, const QString &title,
                  const QVariantMap &options, const QDBusMessage &message, QVariantMap &results);
    uint SaveFiles(const QDBusObjectPath &handle, const QString &app_id, const QString &parent_window, const QString &title,
                   const QVariantMap &options, const QDBusMessage &message, QVariantMap &results);

private:
    void ask(const QString &mode, const QDBusObjectPath &handle, const QString &parentWindow, const QString &title,
             const QVariantMap &options, const QDBusMessage &message);

    QQmlEngine *m_engine;
    QQmlComponent *m_component = nullptr;
    int m_pending = 0;
};

class PendingRequest : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.impl.portal.Request")

public:
    PendingRequest(const QDBusMessage &message, const QDBusObjectPath &handle, const Portal::Filters &filters, QObject *parent);

    void setWindow(QObject *window);

public Q_SLOTS:
    void finished(const QVariant &result);
    Q_SCRIPTABLE void Close();

Q_SIGNALS:
    void done();

private:
    void reply(uint response, const QVariantMap &results);

    QDBusMessage m_message;
    QDBusObjectPath m_handle;
    Portal::Filters m_filters;
    QPointer<QObject> m_window;
    bool m_answered = false;
};
