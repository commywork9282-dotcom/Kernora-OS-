// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "dbus.h"

#include <climits>

#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusMetaType>
#include <QDBusObjectPath>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusSignature>
#include <QDBusVariant>
#include <QJSEngine>
#include <QQmlEngine>

DBus::DBus(QObject *parent)
    : QObject(parent)
{
}

QDBusConnection DBus::connection(const QString &bus)
{
    return bus == QLatin1String("system") ? QDBusConnection::systemBus() : QDBusConnection::sessionBus();
}

static QVariant typed(const QString &type, const QVariant &value)
{
    if (type == QLatin1String("s")) {
        return value.toString();
    }
    if (type == QLatin1String("b")) {
        return value.toBool();
    }
    if (type == QLatin1String("i")) {
        return static_cast<int>(value.toLongLong());
    }
    if (type == QLatin1String("u")) {
        return static_cast<uint>(value.toULongLong());
    }
    if (type == QLatin1String("x")) {
        return static_cast<qlonglong>(value.toLongLong());
    }
    if (type == QLatin1String("t")) {
        return static_cast<qulonglong>(value.toULongLong());
    }
    if (type == QLatin1String("d")) {
        return value.toDouble();
    }
    if (type == QLatin1String("o")) {
        return QVariant::fromValue(QDBusObjectPath(value.toString()));
    }
    if (type == QLatin1String("as")) {
        return value.toStringList();
    }
    if (type == QLatin1String("ai")) {
        QList<int> numbers;
        for (const QVariant &item : value.toList()) {
            numbers.append(item.toInt());
        }
        return QVariant::fromValue(numbers);
    }
    if (type == QLatin1String("ao")) {
        QList<QDBusObjectPath> paths;
        for (const QVariant &item : value.toList()) {
            paths.append(QDBusObjectPath(item.toString()));
        }
        return QVariant::fromValue(paths);
    }
    if (type == QLatin1String("ay")) {
        return value.toByteArray();
    }
    if (type == QLatin1String("a{sv}")) {
        QVariantMap map;
        const QVariantMap source = value.toMap();
        for (auto it = source.cbegin(); it != source.cend(); ++it) {
            map.insert(it.key(), DBus::fromJs(it.value()));
        }
        return map;
    }
    if (type == QLatin1String("v")) {
        return QVariant::fromValue(QDBusVariant(DBus::fromJs(value)));
    }
    return value;
}

QVariant DBus::fromJs(const QVariant &value)
{
    if (value.metaType().id() == QMetaType::QVariantMap) {
        const QVariantMap map = value.toMap();
        if (map.size() == 2 && map.contains(QStringLiteral("type")) && map.contains(QStringLiteral("value"))) {
            return typed(map.value(QStringLiteral("type")).toString(), map.value(QStringLiteral("value")));
        }
        QVariantMap converted;
        for (auto it = map.cbegin(); it != map.cend(); ++it) {
            converted.insert(it.key(), fromJs(it.value()));
        }
        return converted;
    }
    if (value.metaType().id() == QMetaType::QVariantList) {
        const QVariantList list = value.toList();
        bool strings = !list.isEmpty();
        for (const QVariant &item : list) {
            strings = strings && item.metaType().id() == QMetaType::QString;
        }
        if (strings) {
            return value.toStringList();
        }
    }
    if (value.metaType().id() == QMetaType::Double) {
        const double number = value.toDouble();
        if (number == static_cast<qint64>(number) && number >= INT_MIN && number <= INT_MAX) {
            return static_cast<int>(number);
        }
    }
    return value;
}

static QVariant demarshall(const QDBusArgument &argument);

QVariant DBus::toJs(const QVariant &value)
{
    if (value.metaType() == QMetaType::fromType<QDBusArgument>()) {
        return demarshall(value.value<QDBusArgument>());
    }
    if (value.metaType() == QMetaType::fromType<QDBusVariant>()) {
        return toJs(value.value<QDBusVariant>().variant());
    }
    if (value.metaType() == QMetaType::fromType<QDBusObjectPath>()) {
        return value.value<QDBusObjectPath>().path();
    }
    if (value.metaType() == QMetaType::fromType<QDBusSignature>()) {
        return value.value<QDBusSignature>().signature();
    }
    if (value.metaType().id() == QMetaType::QVariantList) {
        QVariantList list;
        for (const QVariant &item : value.toList()) {
            list.append(toJs(item));
        }
        return list;
    }
    if (value.metaType().id() == QMetaType::QVariantMap) {
        QVariantMap map;
        const QVariantMap source = value.toMap();
        for (auto it = source.cbegin(); it != source.cend(); ++it) {
            map.insert(it.key(), toJs(it.value()));
        }
        return map;
    }
    return value;
}

static QVariant demarshall(const QDBusArgument &argument)
{
    switch (argument.currentType()) {
    case QDBusArgument::BasicType:
    case QDBusArgument::VariantType: {
        const QVariant value = argument.asVariant();
        return DBus::toJs(value);
    }
    case QDBusArgument::ArrayType: {
        QVariantList list;
        argument.beginArray();
        while (!argument.atEnd()) {
            list.append(demarshall(argument));
        }
        argument.endArray();
        return list;
    }
    case QDBusArgument::StructureType: {
        QVariantList fields;
        argument.beginStructure();
        while (!argument.atEnd()) {
            fields.append(demarshall(argument));
        }
        argument.endStructure();
        return fields;
    }
    case QDBusArgument::MapType: {
        QVariantMap map;
        argument.beginMap();
        while (!argument.atEnd()) {
            argument.beginMapEntry();
            const QVariant key = demarshall(argument);
            const QVariant value = demarshall(argument);
            argument.endMapEntry();
            map.insert(key.toString(), value);
        }
        argument.endMap();
        return map;
    }
    default:
        return QVariant();
    }
}

void DBus::finish(const QDBusMessage &reply, const QJSValue &callback)
{
    if (!callback.isCallable()) {
        return;
    }
    QJSEngine *engine = qjsEngine(this);
    if (!engine) {
        return;
    }
    QJSValue function = callback;
    if (reply.type() == QDBusMessage::ErrorMessage) {
        function.call({QJSValue(false), QJSValue(reply.errorMessage().isEmpty() ? reply.errorName() : reply.errorMessage())});
        return;
    }
    QVariant result;
    const QVariantList arguments = reply.arguments();
    if (arguments.size() == 1) {
        result = toJs(arguments.first());
    } else if (!arguments.isEmpty()) {
        QVariantList all;
        for (const QVariant &argument : arguments) {
            all.append(toJs(argument));
        }
        result = all;
    }
    function.call({QJSValue(true), engine->toScriptValue(result)});
}

void DBus::call(const QString &bus, const QString &service, const QString &path, const QString &interface,
                const QString &method, const QVariantList &arguments, const QJSValue &callback, bool interactive)
{
    QDBusMessage message = QDBusMessage::createMethodCall(service, path, interface, method);
    QVariantList converted;
    for (const QVariant &argument : arguments) {
        converted.append(fromJs(argument));
    }
    message.setArguments(converted);
    message.setInteractiveAuthorizationAllowed(interactive);
    const int timeout = interactive ? 10 * 60 * 1000 : -1;
    auto *watcher = new QDBusPendingCallWatcher(connection(bus).asyncCall(message, timeout), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, callback](QDBusPendingCallWatcher *self) {
        finish(self->reply(), callback);
        self->deleteLater();
    });
}

void DBus::getProperty(const QString &bus, const QString &service, const QString &path, const QString &interface,
                       const QString &name, const QJSValue &callback)
{
    call(bus, service, path, QStringLiteral("org.freedesktop.DBus.Properties"), QStringLiteral("Get"),
         {interface, name}, callback);
}

void DBus::getAllProperties(const QString &bus, const QString &service, const QString &path, const QString &interface,
                            const QJSValue &callback)
{
    call(bus, service, path, QStringLiteral("org.freedesktop.DBus.Properties"), QStringLiteral("GetAll"),
         {interface}, callback);
}

void DBus::setProperty(const QString &bus, const QString &service, const QString &path, const QString &interface,
                       const QString &name, const QVariant &value, const QJSValue &callback)
{
    QVariantMap wrapped{{QStringLiteral("type"), QStringLiteral("v")}, {QStringLiteral("value"), value}};
    call(bus, service, path, QStringLiteral("org.freedesktop.DBus.Properties"), QStringLiteral("Set"),
         {interface, name, wrapped}, callback);
}

void DBus::emitSignal(const QString &bus, const QString &path, const QString &interface, const QString &name,
                      const QVariantList &arguments)
{
    QDBusMessage message = QDBusMessage::createSignal(path, interface, name);
    QVariantList converted;
    for (const QVariant &argument : arguments) {
        converted.append(fromJs(argument));
    }
    message.setArguments(converted);
    connection(bus).send(message);
}

bool DBus::isServiceRegistered(const QString &bus, const QString &service) const
{
    auto *interface = connection(bus).interface();
    return interface && interface->isServiceRegistered(service);
}
