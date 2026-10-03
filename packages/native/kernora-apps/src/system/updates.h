// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <QObject>
#include <QVariant>
#include <QtQml/qqmlregistration.h>

class Updates : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(State state READ state NOTIFY stateChanged)
    Q_PROPERTY(QVariantList packages READ packages NOTIFY packagesChanged)
    Q_PROPERTY(int progress READ progress NOTIFY progressChanged)
    Q_PROPERTY(QString status READ status NOTIFY progressChanged)
    Q_PROPERTY(QString error READ error NOTIFY stateChanged)
    Q_PROPERTY(bool restartNeeded READ restartNeeded NOTIFY stateChanged)
    Q_PROPERTY(qint64 lastCheck READ lastCheck NOTIFY stateChanged)
    Q_PROPERTY(bool available READ available CONSTANT)

public:
    enum State {
        Idle,
        Checking,
        UpToDate,
        UpdatesAvailable,
        Installing,
        Installed,
        Failed,
    };
    Q_ENUM(State)

    explicit Updates(QObject *parent = nullptr);

    State state() const { return m_state; }
    QVariantList packages() const { return m_packages; }
    int progress() const { return m_progress; }
    QString status() const { return m_status; }
    QString error() const { return m_error; }
    bool restartNeeded() const { return m_restart; }
    qint64 lastCheck() const;
    bool available() const;

    Q_INVOKABLE void check();
    Q_INVOKABLE void install();

Q_SIGNALS:
    void stateChanged();
    void packagesChanged();
    void progressChanged();

private:
    void setState(State state);
    void fetchUpdates();
    void track(QObject *transaction);

    State m_state = Idle;
    QVariantList m_packages;
    QStringList m_ids;
    int m_progress = 0;
    QString m_status;
    QString m_error;
    bool m_restart = false;
};
