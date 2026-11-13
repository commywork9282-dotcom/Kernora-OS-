// SPDX-FileCopyrightText: 2021 Google LLC
// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include <QList>
#include <QRgb>
#include <QString>

class QImage;

namespace Kernora::WallpaperColours
{
struct HueChroma {
    double hue = 0.0;
    double chroma = 0.0;
};

HueChroma hueChroma(QRgb argb);
QList<QRgb> seeds(const QImage &image, int desired = 4);
QList<QRgb> seedsFromFile(const QString &path, int desired = 4);
}
