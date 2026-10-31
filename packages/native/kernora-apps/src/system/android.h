// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <QJSValue>
#include <QObject>
#include <QUrl>
#include <QVariant>
#include <QtQml/qqmlregistration.h>

class QFileSystemWatcher;
class QDBusServiceWatcher;

class Android : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool running READ running NOTIFY runningChanged)
    Q_PROPERTY(QVariantList apps READ apps NOTIFY appsChanged)

public:
    explicit Android(QObject *parent = nullptr);

    bool running() const { return m_running; }
    QVariantList apps() const { return m_apps; }

    Q_INVOKABLE QVariantMap inspect(const QUrl &file) const;
    Q_INVOKABLE bool hasApp(const QString &package) const;
    Q_INVOKABLE void install(const QUrl &file, const QString &package, const QJSValue &callback = QJSValue());
    Q_INVOKABLE bool uninstall(const QString &package);
    Q_INVOKABLE bool launch(const QString &package);
    Q_INVOKABLE bool openSettings();
    Q_INVOKABLE void start(const QJSValue &callback = QJSValue());
    Q_INVOKABLE void stop();
    Q_INVOKABLE void copyText(const QString &text);

Q_SIGNALS:
    void runningChanged();
    void appsChanged();

private:
    void scan();
    void listPackages(const QString &package, const QJSValue &callback);
    QString applicationsFolder() const;

    bool m_running = false;
    QVariantList m_apps;
    QFileSystemWatcher *m_watcher = nullptr;
    QDBusServiceWatcher *m_session = nullptr;
};
