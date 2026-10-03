// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <QObject>
#include <QVariant>
#include <QtQml/qqmlregistration.h>

class Autostart : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit Autostart(QObject *parent = nullptr);

    Q_INVOKABLE QVariantList entries() const;
    Q_INVOKABLE void setEnabled(const QString &id, bool enabled);
    Q_INVOKABLE void add(const QString &storageId);
    Q_INVOKABLE void remove(const QString &id);
    Q_INVOKABLE QVariantList applications() const;

Q_SIGNALS:
    void changed();
};
