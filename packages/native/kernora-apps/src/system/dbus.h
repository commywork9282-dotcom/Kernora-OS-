// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <QDBusArgument>
#include <QDBusConnection>
#include <QJSValue>
#include <QObject>
#include <QVariant>
#include <QtQml/qqmlregistration.h>

class DBus : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit DBus(QObject *parent = nullptr);

    Q_INVOKABLE void call(const QString &bus, const QString &service, const QString &path,
                          const QString &interface, const QString &method,
                          const QVariantList &arguments = {}, const QJSValue &callback = QJSValue(),
                          bool interactive = false);
    Q_INVOKABLE void getProperty(const QString &bus, const QString &service, const QString &path,
                                 const QString &interface, const QString &name, const QJSValue &callback);
    Q_INVOKABLE void getAllProperties(const QString &bus, const QString &service, const QString &path,
                                      const QString &interface, const QJSValue &callback);
    Q_INVOKABLE void setProperty(const QString &bus, const QString &service, const QString &path,
                                 const QString &interface, const QString &name, const QVariant &value,
                                 const QJSValue &callback = QJSValue());
    Q_INVOKABLE void emitSignal(const QString &bus, const QString &path, const QString &interface,
                                const QString &name, const QVariantList &arguments = {});
    Q_INVOKABLE bool isServiceRegistered(const QString &bus, const QString &service) const;

    static QVariant toJs(const QVariant &value);
    static QVariant fromJs(const QVariant &value);

private:
    static QDBusConnection connection(const QString &bus);
    void finish(const QDBusMessage &message, const QJSValue &callback);
};
