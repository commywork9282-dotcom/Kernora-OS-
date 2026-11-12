// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "windowblur.h"

#include <QRegion>
#include <QTimer>

#include <KWindowEffects>

#include <algorithm>
#include <cmath>

static QRegion roundedRegion(const QRect &rect, int radius)
{
    radius = std::min({radius, rect.width() / 2, rect.height() / 2});
    if (radius <= 0) {
        return QRegion(rect);
    }
    QRegion region(rect.adjusted(0, radius, 0, -radius));
    for (int row = 0; row < radius; ++row) {
        const double dy = radius - row - 0.5;
        const int inset = int(std::ceil(radius - std::sqrt(double(radius) * radius - dy * dy)));
        const int width = rect.width() - 2 * inset;
        if (width <= 0) {
            continue;
        }
        region += QRect(rect.x() + inset, rect.y() + row, width, 1);
        region += QRect(rect.x() + inset, rect.bottom() - row, width, 1);
    }
    return region;
}

WindowBlur::WindowBlur(QObject *parent)
    : QObject(parent)
    , m_available(KWindowEffects::isEffectAvailable(KWindowEffects::BlurBehind))
{
}

WindowBlur::~WindowBlur()
{
    if (m_window) {
        KWindowEffects::enableBlurBehind(m_window, false);
    }
}

QWindow *WindowBlur::window() const
{
    return m_window;
}

void WindowBlur::setWindow(QWindow *window)
{
    if (m_window == window) {
        return;
    }
    if (m_window) {
        disconnect(m_window, nullptr, this, nullptr);
        KWindowEffects::enableBlurBehind(m_window, false);
    }
    m_window = window;
    if (m_window) {
        connect(m_window, &QWindow::visibleChanged, this, &WindowBlur::schedule);
    }
    Q_EMIT windowChanged();
    schedule();
}

QRectF WindowBlur::rect() const
{
    return m_rect;
}

void WindowBlur::setRect(const QRectF &rect)
{
    if (m_rect == rect) {
        return;
    }
    m_rect = rect;
    Q_EMIT rectChanged();
    schedule();
}

qreal WindowBlur::radius() const
{
    return m_radius;
}

void WindowBlur::setRadius(qreal radius)
{
    if (qFuzzyCompare(m_radius, radius)) {
        return;
    }
    m_radius = radius;
    Q_EMIT radiusChanged();
    schedule();
}

bool WindowBlur::enabled() const
{
    return m_enabled;
}

void WindowBlur::setEnabled(bool enabled)
{
    if (m_enabled == enabled) {
        return;
    }
    m_enabled = enabled;
    Q_EMIT enabledChanged();
    schedule();
}

bool WindowBlur::available() const
{
    return m_available;
}

void WindowBlur::schedule()
{
    if (m_pending) {
        return;
    }
    m_pending = true;
    QTimer::singleShot(0, this, &WindowBlur::apply);
}

void WindowBlur::apply()
{
    m_pending = false;
    const bool available = KWindowEffects::isEffectAvailable(KWindowEffects::BlurBehind);
    if (available != m_available) {
        m_available = available;
        Q_EMIT availableChanged();
    }
    if (!m_window) {
        return;
    }
    const QRect rect = m_rect.toAlignedRect();
    if (!m_enabled || rect.isEmpty()) {
        KWindowEffects::enableBlurBehind(m_window, false);
        return;
    }
    KWindowEffects::enableBlurBehind(m_window, true, roundedRegion(rect, int(std::round(m_radius))));
}
