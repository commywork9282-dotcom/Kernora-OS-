#pragma once

#include <QObject>
#include <QDBusConnection>
#include <QtQml/qqmlregistration.h>

class BluetoothDiscovery : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString adapterPath READ adapterPath WRITE setAdapterPath NOTIFY configurationChanged)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY configurationChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY stateChanged)
    Q_PROPERTY(bool scanning READ scanning NOTIFY stateChanged)
    Q_PROPERTY(QString errorString READ errorString NOTIFY stateChanged)

public:
    explicit BluetoothDiscovery(QObject *parent = nullptr);
    ~BluetoothDiscovery() override;
    QString adapterPath() const { return m_adapterPath; }
    void setAdapterPath(const QString &path);
    bool active() const { return m_active; }
    void setActive(bool active);
    bool busy() const { return m_busy; }
    bool scanning() const { return !m_ownedPath.isEmpty(); }
    QString errorString() const { return m_error; }
    Q_INVOKABLE void retry();

Q_SIGNALS:
    void configurationChanged();
    void stateChanged();

private:
    void reconcile();
    QString m_busName;
    QDBusConnection m_bus;
    QString m_adapterPath;
    QString m_ownedPath;
    QString m_error;
    bool m_active = false;
    bool m_busy = false;
};
