// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <KFilePlacesModel>
#include <QtQml/qqmlregistration.h>

class Places : public KFilePlacesModel
{
    Q_OBJECT
    QML_ELEMENT

public:
    explicit Places(QObject *parent = nullptr);

    Q_INVOKABLE int groupOf(int row) const;
    Q_INVOKABLE void setup(int row);
    Q_INVOKABLE void unmount(int row);
    Q_INVOKABLE void eject(int row);
    Q_INVOKABLE bool canEject(int row) const;
    Q_INVOKABLE bool canUnmount(int row) const;
    Q_INVOKABLE void addBookmark(const QUrl &url, const QString &name);
    Q_INVOKABLE void removeBookmark(int row);

Q_SIGNALS:
    void ready(int row, bool ok, const QUrl &url);
    void failed(const QString &message);
};
