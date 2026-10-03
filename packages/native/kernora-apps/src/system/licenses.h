// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <QObject>
#include <QVariant>
#include <QtQml/qqmlregistration.h>

class Licenses : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit Licenses(QObject *parent = nullptr);

    Q_INVOKABLE QVariantList components() const;
    Q_INVOKABLE QVariantList packages() const;
    Q_INVOKABLE QString text(const QString &path) const;

private:
    static QString licenseSummary(const QString &copyrightPath);
};
