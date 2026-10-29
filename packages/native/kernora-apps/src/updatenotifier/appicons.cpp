// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "appicons.h"

#include <QBuffer>
#include <QImageReader>
#include <QPainter>
#include <QPainterPath>

#include <algorithm>
#include <cmath>
#include <functional>
#include <vector>

using namespace AppIcons;

namespace
{
constexpr qreal Radius = Size * 22.0 / 48.0;
constexpr qreal GlyphSize = Size * 28.0 / 48.0;
constexpr qreal BackedScale = 0.68;

using Mask = std::vector<int>;

QRectF circleRect()
{
    return QRectF(Size / 2.0 - Radius, Size / 2.0 - Radius, Radius * 2, Radius * 2);
}

QRect bounds(const QImage &image, int threshold)
{
    int left = image.width();
    int top = image.height();
    int right = -1;
    int bottom = -1;
    for (int y = 0; y < image.height(); ++y) {
        const auto *line = reinterpret_cast<const QRgb *>(image.constScanLine(y));
        for (int x = 0; x < image.width(); ++x) {
            if (qAlpha(line[x]) > threshold) {
                left = std::min(left, x);
                right = std::max(right, x);
                top = std::min(top, y);
                bottom = std::max(bottom, y);
            }
        }
    }
    return right < 0 ? QRect() : QRect(QPoint(left, top), QPoint(right, bottom));
}

bool squarish(const QRect &box)
{
    return !box.isEmpty() && qreal(std::min(box.width(), box.height())) / std::max(box.width(), box.height()) > 0.9;
}

bool isRound(const QImage &image, const QRect &box)
{
    if (!squarish(box)) {
        return false;
    }
    const qreal cx = box.width() / 2.0;
    const qreal cy = box.height() / 2.0;
    const qreal r = std::min(box.width(), box.height()) / 2.0;
    qreal inside = 0;
    qreal outside = 0;
    int insideCount = 0;
    int outsideCount = 0;
    for (int y = 0; y < box.height(); y += 2) {
        const auto *line = reinterpret_cast<const QRgb *>(image.constScanLine(box.top() + y));
        for (int x = 0; x < box.width(); x += 2) {
            const qreal distance = std::hypot(x + 0.5 - cx, y + 0.5 - cy);
            const qreal alpha = qAlpha(line[box.left() + x]) / 255.0;
            if (distance < r * 0.94) {
                inside += alpha;
                ++insideCount;
            } else if (distance > r * 1.04) {
                outside += alpha;
                ++outsideCount;
            }
        }
    }
    return inside / std::max(1, insideCount) > 0.97 && outside / std::max(1, outsideCount) < 0.08;
}

QImage fit(const QImage &image, qreal target)
{
    const QImage crop = image.copy(bounds(image, 24));
    const qreal scale = target / std::max(crop.width(), crop.height());
    return crop.scaled(std::max(1, qRound(crop.width() * scale)), std::max(1, qRound(crop.height() * scale)), Qt::IgnoreAspectRatio,
                       Qt::SmoothTransformation);
}

void drawCentred(QPainter &painter, const QImage &item)
{
    painter.drawImage(QPointF((Size - item.width()) / 2, (Size - item.height()) / 2), item);
}

QImage canvas()
{
    QImage image(Size, Size, QImage::Format_ARGB32_Premultiplied);
    image.fill(Qt::transparent);
    return image;
}

void begin(QPainter &painter)
{
    painter.setRenderHint(QPainter::Antialiasing);
    painter.setRenderHint(QPainter::SmoothPixmapTransform);
    painter.setPen(Qt::NoPen);
}

qreal luminance(QRgb pixel)
{
    return 0.2126 * qRed(pixel) + 0.7152 * qGreen(pixel) + 0.0722 * qBlue(pixel);
}

Mask morph(const Mask &mask, int width, int height, int radius, bool grow)
{
    const auto pick = [grow](int a, int b) {
        return grow ? std::max(a, b) : std::min(a, b);
    };
    Mask pass(mask.size());
    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
            int value = mask[y * width + x];
            for (int dx = -radius; dx <= radius; ++dx) {
                value = pick(value, mask[y * width + std::clamp(x + dx, 0, width - 1)]);
            }
            pass[y * width + x] = value;
        }
    }
    Mask result(mask.size());
    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
            int value = pass[y * width + x];
            for (int dy = -radius; dy <= radius; ++dy) {
                value = pick(value, pass[std::clamp(y + dy, 0, height - 1) * width + x]);
            }
            result[y * width + x] = value;
        }
    }
    return result;
}

Mask paintedMask(int width, int height, const std::function<void(QPainter &)> &draw)
{
    QImage image(width, height, QImage::Format_ARGB32_Premultiplied);
    image.fill(Qt::transparent);
    {
        QPainter painter(&image);
        begin(painter);
        painter.setBrush(Qt::black);
        draw(painter);
    }
    Mask mask(width * height);
    for (int y = 0; y < height; ++y) {
        const auto *line = reinterpret_cast<const QRgb *>(image.constScanLine(y));
        for (int x = 0; x < width; ++x) {
            mask[y * width + x] = qAlpha(line[x]);
        }
    }
    return mask;
}

std::vector<QRgb> edgeSamples(const QImage &crop, Shape kind)
{
    std::vector<QRgb> samples;
    const int w = crop.width();
    const int h = crop.height();
    for (int y = 0; y < h; y += 2) {
        const auto *line = reinterpret_cast<const QRgb *>(crop.constScanLine(y));
        for (int x = 0; x < w; x += 2) {
            if (qAlpha(line[x]) < 220) {
                continue;
            }
            bool edge = false;
            if (kind == Shape::Circle) {
                const qreal distance = std::hypot(x - w / 2.0, y - h / 2.0) / (std::min(w, h) / 2.0);
                edge = distance > 0.8 && distance < 0.92;
            } else {
                const qreal margin = qreal(std::min({x, y, w - 1 - x, h - 1 - y})) / std::min(w, h);
                edge = margin > 0.04 && margin < 0.1;
            }
            if (edge) {
                samples.push_back(line[x]);
            }
        }
    }
    return samples;
}

bool contrastMask(const QImage &crop, Shape kind, Mask &mask)
{
    const std::vector<QRgb> samples = edgeSamples(crop, kind);
    if (samples.empty()) {
        return false;
    }
    qreal mean[3] = {0, 0, 0};
    for (QRgb sample : samples) {
        mean[0] += qRed(sample);
        mean[1] += qGreen(sample);
        mean[2] += qBlue(sample);
    }
    for (qreal &channel : mean) {
        channel /= samples.size();
    }
    qreal spread = 0;
    for (QRgb sample : samples) {
        spread += std::sqrt(std::pow(qRed(sample) - mean[0], 2) + std::pow(qGreen(sample) - mean[1], 2) + std::pow(qBlue(sample) - mean[2], 2));
    }
    if (spread / samples.size() >= 40) {
        return false;
    }
    const int w = crop.width();
    const int h = crop.height();
    mask.assign(w * h, 0);
    for (int y = 0; y < h; ++y) {
        const auto *line = reinterpret_cast<const QRgb *>(crop.constScanLine(y));
        for (int x = 0; x < w; ++x) {
            const QRgb pixel = line[x];
            const qreal distance =
                std::sqrt(std::pow(qRed(pixel) - mean[0], 2) + std::pow(qGreen(pixel) - mean[1], 2) + std::pow(qBlue(pixel) - mean[2], 2));
            mask[y * w + x] = int(std::clamp((distance - 50) * 3, 0.0, 255.0) * qAlpha(pixel) / 255);
        }
    }
    const Mask inset = paintedMask(w, h, [kind, w, h](QPainter &painter) {
        if (kind == Shape::Circle) {
            painter.drawEllipse(QRectF(w * 0.07, h * 0.07, w * 0.86, h * 0.86));
        } else {
            painter.drawRoundedRect(QRectF(w * 0.05, h * 0.05, w * 0.9, h * 0.9), w * 0.15, w * 0.15);
        }
    });
    for (std::size_t i = 0; i < mask.size(); ++i) {
        mask[i] = mask[i] * inset[i] / 255;
    }
    mask = morph(morph(mask, w, h, 1, false), w, h, 1, true);
    return true;
}

Mask stampMask(const QImage &crop)
{
    const int w = crop.width();
    const int h = crop.height();
    Mask alpha(w * h);
    std::vector<qreal> values;
    for (int y = 0; y < h; ++y) {
        const auto *line = reinterpret_cast<const QRgb *>(crop.constScanLine(y));
        for (int x = 0; x < w; ++x) {
            alpha[y * w + x] = qAlpha(line[x]);
            if (x % 2 == 0 && y % 2 == 0 && qAlpha(line[x]) > 200) {
                values.push_back(luminance(line[x]));
            }
        }
    }
    if (values.empty()) {
        return alpha;
    }
    std::sort(values.begin(), values.end());
    const qreal low = values[values.size() / 10];
    const qreal high = values[values.size() * 9 / 10];
    if (high - low < 24) {
        return alpha;
    }
    const qreal middle = (low + high) / 2;
    const qreal span = std::max(12.0, (high - low) * 0.12);
    const Mask inner = morph(alpha, w, h, 4, false);
    Mask mask(w * h);
    for (int y = 0; y < h; ++y) {
        const auto *line = reinterpret_cast<const QRgb *>(crop.constScanLine(y));
        for (int x = 0; x < w; ++x) {
            const int i = y * w + x;
            const qreal ink = std::clamp(0.5 + (middle - luminance(line[x])) / span, 0.0, 1.0);
            const int stamp = int(255 * ink * alpha[i] / 255);
            const int edge = alpha[i] * (255 - inner[i]) / 255;
            mask[i] = edge + stamp * (255 - edge) / 255;
        }
    }
    return mask;
}
}

QImage AppIcons::load(const QString &path)
{
    QImageReader reader(path);
    const QSize natural = reader.size();
    if (natural.isValid() && !natural.isEmpty()) {
        reader.setScaledSize(natural.scaled(Size, Size, Qt::KeepAspectRatio));
    }
    QImage image = reader.read();
    if (image.isNull()) {
        return {};
    }
    if (image.width() != Size && image.height() != Size) {
        image = image.scaled(Size, Size, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    }
    QImage result = canvas();
    {
        QPainter painter(&result);
        begin(painter);
        drawCentred(painter, image);
    }
    return result.convertToFormat(QImage::Format_ARGB32);
}

Shape AppIcons::shape(const QImage &icon)
{
    const QRect box = bounds(icon, 24);
    if (isRound(icon, box)) {
        return Shape::Circle;
    }
    if (squarish(box)) {
        int filled = 0;
        for (int y = box.top(); y <= box.bottom(); ++y) {
            const auto *line = reinterpret_cast<const QRgb *>(icon.constScanLine(y));
            for (int x = box.left(); x <= box.right(); ++x) {
                filled += qAlpha(line[x]) > 200;
            }
        }
        if (qreal(filled) / (box.width() * box.height()) > 0.86) {
            return Shape::Square;
        }
    }
    return Shape::Free;
}

QImage AppIcons::standard(const QImage &icon)
{
    QImage result = canvas();
    QPainter painter(&result);
    begin(painter);
    if (shape(icon) == Shape::Circle) {
        drawCentred(painter, fit(icon, Radius * 2));
        QImage clip = canvas();
        {
            QPainter clipPainter(&clip);
            begin(clipPainter);
            clipPainter.setBrush(Qt::black);
            clipPainter.drawEllipse(circleRect());
        }
        painter.setCompositionMode(QPainter::CompositionMode_DestinationIn);
        painter.drawImage(0, 0, clip);
    } else {
        painter.setBrush(Qt::white);
        painter.drawEllipse(circleRect());
        drawCentred(painter, fit(icon, Radius * 2 * BackedScale));
    }
    painter.end();
    return result.convertToFormat(QImage::Format_ARGB32);
}

QImage AppIcons::themed(const QImage &icon, const Palette &palette)
{
    const Shape kind = shape(icon);
    const QImage crop = icon.copy(bounds(icon, 24));
    Mask mask;
    if (kind == Shape::Free || !contrastMask(crop, kind, mask)) {
        mask = stampMask(crop);
    }
    QImage glyph(crop.size(), QImage::Format_ARGB32);
    for (int y = 0; y < crop.height(); ++y) {
        auto *line = reinterpret_cast<QRgb *>(glyph.scanLine(y));
        for (int x = 0; x < crop.width(); ++x) {
            line[x] = qRgba(palette.ink.red(), palette.ink.green(), palette.ink.blue(), mask[y * crop.width() + x]);
        }
    }
    const QRect box = bounds(glyph, 40);
    glyph = glyph.copy(box.isEmpty() ? glyph.rect() : box);
    const qreal scale = GlyphSize / std::max(glyph.width(), glyph.height());
    glyph = glyph.scaled(std::max(1, qRound(glyph.width() * scale)), std::max(1, qRound(glyph.height() * scale)), Qt::IgnoreAspectRatio,
                         Qt::SmoothTransformation);
    QImage result = canvas();
    QPainter painter(&result);
    begin(painter);
    painter.setBrush(palette.container);
    painter.drawEllipse(circleRect());
    drawCentred(painter, glyph);
    painter.end();
    return result.convertToFormat(QImage::Format_ARGB32);
}

QByteArray AppIcons::svg(const QImage &icon)
{
    QByteArray png;
    QBuffer buffer(&png);
    buffer.open(QIODevice::WriteOnly);
    icon.save(&buffer, "PNG");
    return QByteArrayLiteral("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
                             "<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" "
                             "width=\"48\" height=\"48\" viewBox=\"0 0 48 48\">\n"
                             "  <image width=\"48\" height=\"48\" xlink:href=\"data:image/png;base64,")
        + png.toBase64() + QByteArrayLiteral("\"/>\n</svg>\n");
}
