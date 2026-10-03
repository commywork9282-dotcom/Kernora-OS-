// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <QObject>
#include <QVariant>
#include <QtQml/qqmlregistration.h>

class DefaultApps : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit DefaultApps(QObject *parent = nullptr);

    Q_INVOKABLE QVariantList categories() const;
    Q_INVOKABLE QVariantList candidates(const QString &category) const;
    Q_INVOKABLE QString current(const QString &category) const;
    Q_INVOKABLE QVariantMap currentApplication(const QString &category) const;
    Q_INVOKABLE void setDefault(const QString &category, const QString &storageId);
    Q_INVOKABLE QVariantList applicationsFor(const QUrl &url) const;

Q_SIGNALS:
    void changed(const QString &category);

private:
    static QStringList mimeTypes(const QString &category);
};
