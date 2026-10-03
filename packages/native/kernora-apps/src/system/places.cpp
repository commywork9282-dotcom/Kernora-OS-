// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "places.h"

Places::Places(QObject *parent)
    : KFilePlacesModel(parent)
{
    connect(this, &KFilePlacesModel::setupDone, this, [this](const QModelIndex &index, bool success) {
        Q_EMIT ready(index.row(), success, url(index));
    });
    connect(this, &KFilePlacesModel::errorMessage, this, &Places::failed);
}

int Places::groupOf(int row) const
{
    return static_cast<int>(groupType(index(row, 0)));
}

void Places::setup(int row)
{
    requestSetup(index(row, 0));
}

void Places::unmount(int row)
{
    requestTeardown(index(row, 0));
}

void Places::eject(int row)
{
    requestEject(index(row, 0));
}

bool Places::canEject(int row) const
{
    return isEjectAllowed(index(row, 0));
}

bool Places::canUnmount(int row) const
{
    return isTeardownAllowed(index(row, 0));
}

void Places::addBookmark(const QUrl &url, const QString &name)
{
    addPlace(name, url);
}

void Places::removeBookmark(int row)
{
    removePlace(index(row, 0));
}
