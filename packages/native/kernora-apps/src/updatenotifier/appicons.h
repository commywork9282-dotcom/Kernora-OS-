// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <QByteArray>
#include <QColor>
#include <QImage>
#include <QString>

namespace AppIcons
{
enum class Shape {
    Circle,
    Square,
    Free,
};

struct Palette {
    QColor container;
    QColor ink;
};

inline constexpr int Size = 256;

QImage load(const QString &path);
Shape shape(const QImage &icon);
QImage standard(const QImage &icon);
QImage themed(const QImage &icon, const Palette &palette);
QByteArray svg(const QImage &icon);
}
