#include "bluetoothdiscovery.h"

#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QUuid>

BluetoothDiscovery::BluetoothDiscovery(QObject *parent)
    : QObject(parent)
    , m_busName(QStringLiteral("kernora-bluetooth-discovery-%1").arg(QUuid::createUuid().toString(QUuid::WithoutBraces)))
    , m_bus(QDBusConnection::connectToBus(QDBusConnection::SystemBus, m_busName))
{
}

BluetoothDiscovery::~BluetoothDiscovery()
{
    QDBusConnection::disconnectFromBus(m_busName);
}

void BluetoothDiscovery::setAdapterPath(const QString &path)
{
    if (m_adapterPath == path) {
        return;
    }
    m_adapterPath = path;
    m_error.clear();
    Q_EMIT configurationChanged();
    Q_EMIT stateChanged();
    reconcile();
}

void BluetoothDiscovery::setActive(bool active)
{
    if (m_active == active) {
        return;
    }
    m_active = active;
    m_error.clear();
    Q_EMIT configurationChanged();
    Q_EMIT stateChanged();
    reconcile();
}

void BluetoothDiscovery::retry()
{
    m_error.clear();
    Q_EMIT stateChanged();
    reconcile();
}

void BluetoothDiscovery::reconcile()
{
    if (m_busy) {
        return;
    }
    const QString wanted = m_active ? m_adapterPath : QString();
    if (!m_ownedPath.isEmpty() && m_ownedPath != wanted) {
        const QString path = m_ownedPath;
        m_busy = true;
        Q_EMIT stateChanged();
        const auto message = QDBusMessage::createMethodCall(QStringLiteral("org.bluez"), path,
                                                           QStringLiteral("org.bluez.Adapter1"), QStringLiteral("StopDiscovery"));
        auto *watcher = new QDBusPendingCallWatcher(m_bus.asyncCall(message), this);
        connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *call) {
            const QDBusPendingReply<> reply = *call;
            call->deleteLater();
            if (reply.isError()) {
                QDBusConnection::disconnectFromBus(m_busName);
                m_busName = QStringLiteral("kernora-bluetooth-discovery-%1").arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
                m_bus = QDBusConnection::connectToBus(QDBusConnection::SystemBus, m_busName);
            }
            m_ownedPath.clear();
            m_busy = false;
            Q_EMIT stateChanged();
            reconcile();
        });
        return;
    }
    if (wanted.isEmpty() || m_ownedPath == wanted || !m_error.isEmpty()) {
        return;
    }
    m_busy = true;
    Q_EMIT stateChanged();
    const auto message = QDBusMessage::createMethodCall(QStringLiteral("org.bluez"), wanted,
                                                       QStringLiteral("org.bluez.Adapter1"), QStringLiteral("StartDiscovery"));
    auto *watcher = new QDBusPendingCallWatcher(m_bus.asyncCall(message), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, wanted](QDBusPendingCallWatcher *call) {
        const QDBusPendingReply<> reply = *call;
        call->deleteLater();
        m_busy = false;
        if (reply.isError()) {
            if (m_active && m_adapterPath == wanted) {
                m_error = reply.error().message();
            }
        } else {
            m_ownedPath = wanted;
        }
        Q_EMIT stateChanged();
        reconcile();
    });
}
