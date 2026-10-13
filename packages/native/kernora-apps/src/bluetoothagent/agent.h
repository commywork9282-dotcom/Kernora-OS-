// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <BluezQt/Agent>
#include <BluezQt/Device>
#include <BluezQt/Request>

#include <QDBusObjectPath>
#include <QObject>

#include <optional>

class PairingAgent : public BluezQt::Agent
{
    Q_OBJECT
    Q_PROPERTY(bool active READ isActive NOTIFY changed)
    Q_PROPERTY(QString kind READ kind NOTIFY changed)
    Q_PROPERTY(QString deviceName READ deviceName NOTIFY changed)
    Q_PROPERTY(QString deviceAddress READ deviceAddress NOTIFY changed)
    Q_PROPERTY(QString code READ code NOTIFY changed)
    Q_PROPERTY(int entered READ entered NOTIFY changed)

public:
    explicit PairingAgent(QObject *parent = nullptr);

    QDBusObjectPath objectPath() const override;
    Capability capability() const override;

    void requestPinCode(BluezQt::DevicePtr device, const BluezQt::Request<QString> &request) override;
    void displayPinCode(BluezQt::DevicePtr device, const QString &pinCode) override;
    void requestPasskey(BluezQt::DevicePtr device, const BluezQt::Request<quint32> &request) override;
    void displayPasskey(BluezQt::DevicePtr device, const QString &passkey, const QString &entered) override;
    void requestConfirmation(BluezQt::DevicePtr device, const QString &passkey, const BluezQt::Request<> &request) override;
    void requestAuthorization(BluezQt::DevicePtr device, const BluezQt::Request<> &request) override;
    void authorizeService(BluezQt::DevicePtr device, const QString &uuid, const BluezQt::Request<> &request) override;
    void cancel() override;
    void release() override;

    bool isActive() const;
    QString kind() const;
    QString deviceName() const;
    QString deviceAddress() const;
    QString code() const;
    int entered() const;

    Q_INVOKABLE void respond(const QString &value);
    Q_INVOKABLE void decline();

Q_SIGNALS:
    void changed();
    void released();

private:
    void begin(const QString &kind, const BluezQt::DevicePtr &device, const QString &code = QString());
    void rejectPending();
    void clear();

    QString m_kind;
    QString m_code;
    int m_entered = 0;
    BluezQt::DevicePtr m_device;
    QMetaObject::Connection m_pairedWatch;
    std::optional<BluezQt::Request<QString>> m_pin;
    std::optional<BluezQt::Request<quint32>> m_passkey;
    std::optional<BluezQt::Request<>> m_confirmation;
};
