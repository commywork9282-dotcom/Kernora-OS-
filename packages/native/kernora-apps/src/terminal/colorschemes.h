// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <QColor>
#include <QList>
#include <QString>
#include <QStringList>
#include <QVariantList>

class ColorSchemes
{
public:
    struct Scheme {
        QString id;
        QString name;
        bool preset = false;
        QColor background;
        QColor foreground;
        QList<QColor> normal;
        QList<QColor> bright;
    };

    ColorSchemes();

    void reload();
    QVariantList list() const;
    const Scheme *find(const QString &id) const;
    QString directory() const;
    QStringList import(const QStringList &files, QString *error);

private:
    static bool parse(const QString &path, Scheme *scheme);
    static QString prettyName(const QString &fileName);
    void write(const Scheme &scheme) const;

    QList<Scheme> m_schemes;
};
