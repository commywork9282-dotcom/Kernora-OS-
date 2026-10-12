// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "appmodel.h"

AppModel::AppModel(QObject *parent)
    : QAbstractListModel(parent)
{
    m_timer.setSingleShot(true);
    m_timer.setInterval(0);
    connect(&m_timer, &QTimer::timeout, this, &AppModel::reload);
    Store *store = Store::instance();
    connect(store, &Store::catalogChanged, this, &AppModel::schedule);
    connect(store, &Store::appChanged, this, [this](const QString &id) {
        if (m_filter != Store::All) {
            schedule();
        }
        const qsizetype row = m_ids.indexOf(id);
        if (row >= 0) {
            Q_EMIT dataChanged(index(int(row)), index(int(row)));
        }
    });
    schedule();
}

void AppModel::schedule()
{
    m_timer.start();
}

void AppModel::setSearch(const QString &search)
{
    if (m_search == search) {
        return;
    }
    m_search = search;
    Q_EMIT searchChanged();
    m_timer.setInterval(120);
    schedule();
}

void AppModel::setCategory(const QString &category)
{
    if (m_category == category) {
        return;
    }
    m_category = category;
    Q_EMIT categoryChanged();
    schedule();
}

void AppModel::setCollection(const QString &collection)
{
    if (m_collection == collection) {
        return;
    }
    m_collection = collection;
    Q_EMIT collectionChanged();
    schedule();
}

void AppModel::setFilter(Store::Filter filter)
{
    if (m_filter == filter) {
        return;
    }
    m_filter = filter;
    Q_EMIT filterChanged();
    schedule();
}

void AppModel::setLimit(int limit)
{
    if (m_limit == limit) {
        return;
    }
    m_limit = limit;
    Q_EMIT limitChanged();
    schedule();
}

void AppModel::reload()
{
    m_timer.setInterval(0);
    Store *store = Store::instance();
    QStringList ids;
    if (!m_collection.isEmpty()) {
        ids = store->collection(m_collection);
    } else if (!m_search.trimmed().isEmpty() || !m_category.isEmpty() || m_filter != Store::All) {
        ids = store->query(m_search, m_category, m_filter);
    }
    m_total = int(ids.size());
    if (m_limit > 0 && ids.size() > m_limit) {
        ids = ids.mid(0, m_limit);
    }
    if (ids == m_ids) {
        Q_EMIT countChanged();
        if (!ids.isEmpty()) {
            Q_EMIT dataChanged(index(0), index(int(ids.size()) - 1));
        }
        return;
    }
    beginResetModel();
    m_ids = ids;
    endResetModel();
    Q_EMIT countChanged();
}

int AppModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : int(m_ids.size());
}

QVariant AppModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_ids.size()) {
        return QVariant();
    }
    return Store::instance()->value(m_ids.at(index.row()), role);
}

QHash<int, QByteArray> AppModel::roleNames() const
{
    return {
        {Store::IdRole, "appId"},
        {Store::NameRole, "name"},
        {Store::SummaryRole, "summary"},
        {Store::IconRole, "iconSource"},
        {Store::DeveloperRole, "developer"},
        {Store::InstalledRole, "installed"},
        {Store::BusyRole, "busy"},
        {Store::ProgressRole, "progress"},
        {Store::StatusRole, "status"},
        {Store::UpdateRole, "hasUpdate"},
        {Store::VerifiedRole, "verified"},
        {Store::SourceRole, "source"},
        {Store::RatingRole, "rating"},
        {Store::AccentRole, "accent"},
    };
}
