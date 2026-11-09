// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <QJSValue>
#include <QObject>
#include <QVariant>
#include <QtQml/qqmlregistration.h>

class AppGroups : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit AppGroups(QObject *parent = nullptr);

    Q_INVOKABLE bool drop(const QString &target, const QStringList &sources);
    Q_INVOKABLE QVariantMap group(const QString &groupFile) const;
    Q_INVOKABLE bool rename(const QString &groupFile, const QString &name);
    Q_INVOKABLE void launch(const QString &groupFile, const QString &app, const QJSValue &callback = QJSValue());
    Q_INVOKABLE bool takeOut(const QString &groupFile, const QString &app);
    Q_INVOKABLE bool ungroup(const QString &groupFile);
};
