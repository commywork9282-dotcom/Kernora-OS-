// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <QImage>
#include <QString>
#include <QStringList>

namespace Apk
{
struct Package {
    QString error;
    QString packageName;
    QString label;
    QString versionName;
    qint64 versionCode = 0;
    int minSdk = 0;
    int targetSdk = 0;
    QStringList abis;
    QImage icon;
};

Package read(const QString &path, const QString &language, int iconSize);
}
