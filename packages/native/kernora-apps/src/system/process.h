// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <QJSValue>
#include <QObject>
#include <QVariant>
#include <QUrl>
#include <QtQml/qqmlregistration.h>

class Process : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit Process(QObject *parent = nullptr);

    Q_INVOKABLE void run(const QString &program, const QStringList &arguments,
                         const QJSValue &callback = QJSValue(), const QString &input = QString());
    Q_INVOKABLE bool startDetached(const QString &program, const QStringList &arguments = {});
    Q_INVOKABLE void openUrl(const QUrl &url);
    Q_INVOKABLE bool launchApplication(const QString &storageId, const QList<QUrl> &urls = {});
    Q_INVOKABLE QVariantMap application(const QString &desktopEntry) const;
    Q_INVOKABLE void openModule(const QString &module);
    Q_INVOKABLE QVariantList settingsModules() const;
    Q_INVOKABLE QString findExecutable(const QString &name) const;
    Q_INVOKABLE QString environment(const QString &name) const;
};
