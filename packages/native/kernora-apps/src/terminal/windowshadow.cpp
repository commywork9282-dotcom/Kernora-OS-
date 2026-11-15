// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "windowshadow.h"

#include <QImage>
#include <QWindow>

#include <KWindowShadow>

#include <array>
#include <cmath>

namespace
{
constexpr int side = 20;
constexpr int top = 20;
constexpr int bottom = 40;
constexpr int radius = 12;
constexpr std::array<std::pair<double, double>, 6> stops{{{0.0, 1.0}, {0.14, 0.72}, {0.32, 0.40}, {0.52, 0.17}, {0.74, 0.05}, {1.0, 0.0}}};

double falloff(double t)
{
    if (t <= 0) {
        return 1;
    }
    for (std::size_t i = 1; i < stops.size(); ++i) {
        if (t <= stops[i].first) {
            const auto [a, va] = stops[i - 1];
            const auto [b, vb] = stops[i];
            return va + (vb - va) * (t - a) / (b - a);
        }
    }
    return 0;
}

QImage shadowImage(qreal ratio, double strength)
{
    const int inner = 2 * radius + 1;
    const QSize logical(2 * side + inner, top + inner + bottom);
    QImage image(QSize(std::ceil(logical.width() * ratio), std::ceil(logical.height() * ratio)), QImage::Format_ARGB32_Premultiplied);
    image.fill(Qt::transparent);
    const double left = side;
    const double right = side + inner;
    const double upper = top;
    const double lower = top + inner;
    for (int py = 0; py < image.height(); ++py) {
        auto *line = reinterpret_cast<QRgb *>(image.scanLine(py));
        for (int px = 0; px < image.width(); ++px) {
            const double x = (px + 0.5) / ratio;
            const double y = (py + 0.5) / ratio;
            const double padX = side;
            const double padY = y < upper + radius ? top : bottom;
            const double cx = std::clamp(x, left + radius, right - radius);
            const double cy = std::clamp(y, upper + radius, lower - radius);
            const double dx = x - cx;
            const double dy = y - cy;
            const double length = std::hypot(dx, dy);
            if (length <= radius) {
                continue;
            }
            const double fx = dx / length;
            const double fy = dy / length;
            const double reach = std::hypot(padX * fx, padY * fy);
            const double alpha = strength * falloff((length - radius) / reach);
            const int a = std::clamp(int(std::lround(alpha * 255)), 0, 255);
            line[px] = qRgba(0, 0, 0, a);
        }
    }
    image.setDevicePixelRatio(ratio);
    return image;
}

KWindowShadowTile::Ptr tile(const QImage &source, const QRect &logical, qreal ratio)
{
    const QRect area(std::floor(logical.x() * ratio), std::floor(logical.y() * ratio), std::ceil(logical.width() * ratio), std::ceil(logical.height() * ratio));
    QImage part = source.copy(area);
    part.setDevicePixelRatio(ratio);
    auto result = KWindowShadowTile::Ptr::create();
    result->setImage(part);
    return result;
}
}

WindowShadow::WindowShadow(QObject *parent)
    : QObject(parent)
{
}

WindowShadow::~WindowShadow()
{
    delete m_shadow;
}

QMargins WindowShadow::padding()
{
    return QMargins(side, top, side, bottom);
}

void WindowShadow::attach(QWindow *window)
{
    if (m_window == window) {
        return;
    }
    m_window = window;
    rebuild();
}

void WindowShadow::setActive(bool active)
{
    if (m_active == active) {
        return;
    }
    m_active = active;
    rebuild();
}

void WindowShadow::setVisible(bool visible)
{
    if (m_visible == visible) {
        return;
    }
    m_visible = visible;
    rebuild();
}

void WindowShadow::rebuild()
{
    delete m_shadow;
    m_shadow = nullptr;
    if (!m_window || !m_visible) {
        return;
    }
    const qreal ratio = m_window->devicePixelRatio();
    const QImage image = shadowImage(ratio, m_active ? 0.50 : 0.28);
    const int inner = 2 * radius + 1;
    const int width = 2 * side + inner;
    const int height = top + inner + bottom;
    const int cornerW = side + radius;
    m_shadow = new KWindowShadow(this);
    m_shadow->setTopLeftTile(tile(image, QRect(0, 0, cornerW, top + radius), ratio));
    m_shadow->setTopTile(tile(image, QRect(cornerW, 0, 1, top), ratio));
    m_shadow->setTopRightTile(tile(image, QRect(width - cornerW, 0, cornerW, top + radius), ratio));
    m_shadow->setLeftTile(tile(image, QRect(0, top + radius, side, 1), ratio));
    m_shadow->setRightTile(tile(image, QRect(width - side, top + radius, side, 1), ratio));
    m_shadow->setBottomLeftTile(tile(image, QRect(0, height - bottom - radius, cornerW, bottom + radius), ratio));
    m_shadow->setBottomTile(tile(image, QRect(cornerW, height - bottom, 1, bottom), ratio));
    m_shadow->setBottomRightTile(tile(image, QRect(width - cornerW, height - bottom - radius, cornerW, bottom + radius), ratio));
    m_shadow->setPadding(padding());
    m_shadow->setWindow(m_window);
    if (!m_shadow->create()) {
        qWarning("kernora-terminal: the window shadow could not be created");
    }
}
