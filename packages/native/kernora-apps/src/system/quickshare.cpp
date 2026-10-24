// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "quickshare.h"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusServiceWatcher>
#include <QJsonDocument>
#include <QJsonObject>
#include <QQmlEngine>

static const QString s_service = QStringLiteral("org.kernora.QuickShare");
static const QString s_path = QStringLiteral("/org/kernora/QuickShare");
static const QString s_interface = QStringLiteral("org.kernora.QuickShare1");

QuickShare::QuickShare(QObject *parent)
    : QObject(parent)
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    bus.connect(s_service, s_path, s_interface, QStringLiteral("Changed"), this, SLOT(onChanged(QString)));
    m_watcher = new QDBusServiceWatcher(s_service, bus,
                                        QDBusServiceWatcher::WatchForRegistration | QDBusServiceWatcher::WatchForUnregistration, this);
    connect(m_watcher, &QDBusServiceWatcher::serviceRegistered, this, &QuickShare::refresh);
    connect(m_watcher, &QDBusServiceWatcher::serviceUnregistered, this, [this] {
        m_available = false;
        m_state.clear();
        Q_EMIT changed();
    });
    refresh();
}

void QuickShare::refresh()
{
    QDBusMessage message = QDBusMessage::createMethodCall(s_service, s_path, s_interface, QStringLiteral("State"));
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(message), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *call) {
        QDBusPendingReply<QString> reply = *call;
        call->deleteLater();
        if (reply.isError()) {
            if (m_available) {
                m_available = false;
                Q_EMIT changed();
            }
            return;
        }
        apply(reply.value());
    });
}

void QuickShare::onChanged(const QString &state)
{
    apply(state);
}

void QuickShare::apply(const QString &state)
{
    const QJsonDocument document = QJsonDocument::fromJson(state.toUtf8());
    if (!document.isObject()) {
        return;
    }
    m_state = document.object().toVariantMap();
    m_available = true;
    Q_EMIT changed();
}

void QuickShare::call(const QString &method, const QVariantList &arguments)
{
    QDBusMessage message = QDBusMessage::createMethodCall(s_service, s_path, s_interface, method);
    message.setArguments(arguments);
    QDBusConnection::sessionBus().asyncCall(message);
}

void QuickShare::setEnabled(bool enabled)
{
    call(QStringLiteral("SetEnabled"), {enabled});
}

void QuickShare::setHighVisibility(bool on)
{
    call(QStringLiteral("SetHighVisibility"), {on});
}

void QuickShare::setVisibility(const QString &mode)
{
    call(QStringLiteral("SetVisibility"), {mode});
}

void QuickShare::setName(const QString &name)
{
    call(QStringLiteral("SetDeviceName"), {name});
}

void QuickShare::setFolder(const QUrl &folder)
{
    call(QStringLiteral("SetDownloadFolder"), {folder.isLocalFile() ? folder.toLocalFile() : folder.toString()});
}

void QuickShare::setAskNearby(bool enabled)
{
    call(QStringLiteral("SetAskNearby"), {enabled});
}

void QuickShare::startDiscovery()
{
    call(QStringLiteral("StartDiscovery"));
}

void QuickShare::stopDiscovery()
{
    call(QStringLiteral("StopDiscovery"));
}

void QuickShare::send(const QString &device, const QVariantList &files, const QJSValue &callback)
{
    QStringList paths;
    for (const QVariant &file : files) {
        const QUrl url = file.toUrl();
        const QString path = url.isLocalFile() ? url.toLocalFile() : file.toString();
        if (!path.isEmpty()) {
            paths.append(path);
        }
    }
    QDBusMessage message = QDBusMessage::createMethodCall(s_service, s_path, s_interface, QStringLiteral("Send"));
    message.setArguments({device, paths});
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(message), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, callback](QDBusPendingCallWatcher *call) {
        QDBusPendingReply<QString> reply = *call;
        call->deleteLater();
        if (callback.isCallable() && qjsEngine(this)) {
            QJSValue function = callback;
            function.call({QJSValue(reply.isError() ? QString() : reply.value())});
        }
    });
}

void QuickShare::accept(const QString &transfer)
{
    call(QStringLiteral("Accept"), {transfer});
}

void QuickShare::decline(const QString &transfer)
{
    call(QStringLiteral("Decline"), {transfer});
}

void QuickShare::cancel(const QString &transfer)
{
    call(QStringLiteral("Cancel"), {transfer});
}

void QuickShare::dismiss(const QString &transfer)
{
    call(QStringLiteral("Dismiss"), {transfer});
}
