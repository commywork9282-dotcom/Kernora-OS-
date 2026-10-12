// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include "store.h"

#include <QAbstractListModel>
#include <QStringList>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

class AppModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString search READ search WRITE setSearch NOTIFY searchChanged)
    Q_PROPERTY(QString category READ category WRITE setCategory NOTIFY categoryChanged)
    Q_PROPERTY(QString collection READ collection WRITE setCollection NOTIFY collectionChanged)
    Q_PROPERTY(Store::Filter filter READ filter WRITE setFilter NOTIFY filterChanged)
    Q_PROPERTY(int limit READ limit WRITE setLimit NOTIFY limitChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(int total READ total NOTIFY countChanged)

public:
    explicit AppModel(QObject *parent = nullptr);

    QString search() const { return m_search; }
    void setSearch(const QString &search);
    QString category() const { return m_category; }
    void setCategory(const QString &category);
    QString collection() const { return m_collection; }
    void setCollection(const QString &collection);
    Store::Filter filter() const { return m_filter; }
    void setFilter(Store::Filter filter);
    int limit() const { return m_limit; }
    void setLimit(int limit);
    int count() const { return int(m_ids.size()); }
    int total() const { return m_total; }

    Q_INVOKABLE QString idAt(int row) const { return m_ids.value(row); }

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

Q_SIGNALS:
    void searchChanged();
    void categoryChanged();
    void collectionChanged();
    void filterChanged();
    void limitChanged();
    void countChanged();

private:
    void schedule();
    void reload();

    QString m_search;
    QString m_category;
    QString m_collection;
    Store::Filter m_filter = Store::All;
    int m_limit = 0;
    int m_total = 0;
    QStringList m_ids;
    QTimer m_timer;
};
