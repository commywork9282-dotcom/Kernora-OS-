// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "agent.h"

PairingAgent::PairingAgent(QObject *parent)
    : BluezQt::Agent(parent)
{
}

QDBusObjectPath PairingAgent::objectPath() const
{
    return QDBusObjectPath(QStringLiteral("/org/kernora/bluetooth/agent"));
}

BluezQt::Agent::Capability PairingAgent::capability() const
{
    return KeyboardDisplay;
}

void PairingAgent::requestPinCode(BluezQt::DevicePtr device, const BluezQt::Request<QString> &request)
{
    rejectPending();
    m_pin = request;
    begin(QStringLiteral("enterPin"), device);
}

void PairingAgent::displayPinCode(BluezQt::DevicePtr device, const QString &pinCode)
{
    rejectPending();
    begin(QStringLiteral("showPin"), device, pinCode);
}

void PairingAgent::requestPasskey(BluezQt::DevicePtr device, const BluezQt::Request<quint32> &request)
{
    rejectPending();
    m_passkey = request;
    begin(QStringLiteral("enterPasskey"), device);
}

void PairingAgent::displayPasskey(BluezQt::DevicePtr device, const QString &passkey, const QString &entered)
{
    if (m_kind == QLatin1String("showPasskey") && m_device == device) {
        m_code = passkey;
        m_entered = entered.toInt();
        Q_EMIT changed();
        return;
    }
    rejectPending();
    begin(QStringLiteral("showPasskey"), device, passkey);
    m_entered = entered.toInt();
    Q_EMIT changed();
}

void PairingAgent::requestConfirmation(BluezQt::DevicePtr device, const QString &passkey, const BluezQt::Request<> &request)
{
    rejectPending();
    m_confirmation = request;
    begin(QStringLiteral("confirmPasskey"), device, passkey);
}

void PairingAgent::requestAuthorization(BluezQt::DevicePtr device, const BluezQt::Request<> &request)
{
    rejectPending();
    m_confirmation = request;
    begin(QStringLiteral("authorizePairing"), device);
}

void PairingAgent::authorizeService(BluezQt::DevicePtr device, const QString &uuid, const BluezQt::Request<> &request)
{
    Q_UNUSED(uuid)
    if (device->isPaired() && device->isTrusted()) {
        request.accept();
        return;
    }
    rejectPending();
    m_confirmation = request;
    begin(QStringLiteral("authorizeService"), device);
}

void PairingAgent::cancel()
{
    m_pin.reset();
    m_passkey.reset();
    m_confirmation.reset();
    clear();
}

void PairingAgent::release()
{
    cancel();
    Q_EMIT released();
}

bool PairingAgent::isActive() const
{
    return !m_kind.isEmpty();
}

QString PairingAgent::kind() const
{
    return m_kind;
}

QString PairingAgent::deviceName() const
{
    if (!m_device) {
        return QString();
    }
    return m_device->name().isEmpty() ? m_device->address() : m_device->name();
}

QString PairingAgent::deviceAddress() const
{
    return m_device ? m_device->address() : QString();
}

QString PairingAgent::code() const
{
    return m_code;
}

int PairingAgent::entered() const
{
    return m_entered;
}

void PairingAgent::respond(const QString &value)
{
    if (m_pin) {
        const QString pin = value.trimmed();
        if (pin.isEmpty() || pin.size() > 16) {
            return;
        }
        m_pin->accept(pin);
        m_pin.reset();
    } else if (m_passkey) {
        bool ok = false;
        const uint passkey = value.trimmed().toUInt(&ok);
        if (!ok || passkey > 999999) {
            return;
        }
        m_passkey->accept(passkey);
        m_passkey.reset();
    } else if (m_confirmation) {
        if (m_device && m_kind == QLatin1String("authorizePairing")) {
            m_device->setTrusted(true);
        }
        m_confirmation->accept();
        m_confirmation.reset();
    }
    clear();
}

void PairingAgent::decline()
{
    rejectPending();
    clear();
}

void PairingAgent::begin(const QString &kind, const BluezQt::DevicePtr &device, const QString &code)
{
    QObject::disconnect(m_pairedWatch);
    m_kind = kind;
    m_device = device;
    m_code = code;
    m_entered = 0;
    if (device && kind.startsWith(QLatin1String("show"))) {
        m_pairedWatch = connect(device.data(), &BluezQt::Device::pairedChanged, this, [this](bool paired) {
            if (paired) {
                clear();
            }
        });
    }
    Q_EMIT changed();
}

void PairingAgent::rejectPending()
{
    if (m_pin) {
        m_pin->reject();
        m_pin.reset();
    }
    if (m_passkey) {
        m_passkey->reject();
        m_passkey.reset();
    }
    if (m_confirmation) {
        m_confirmation->reject();
        m_confirmation.reset();
    }
}

void PairingAgent::clear()
{
    QObject::disconnect(m_pairedWatch);
    if (m_kind.isEmpty()) {
        return;
    }
    m_kind.clear();
    m_code.clear();
    m_entered = 0;
    m_device.clear();
    Q_EMIT changed();
}
