// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <KConfigWatcher>
#include <QObject>
#include <QPointer>
#include <QRectF>
#include <QWindow>
#include <QtQml/qqmlregistration.h>

class WindowBlur : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QWindow *window READ window WRITE setWindow NOTIFY windowChanged)
    Q_PROPERTY(QRectF rect READ rect WRITE setRect NOTIFY rectChanged)
    Q_PROPERTY(qreal radius READ radius WRITE setRadius NOTIFY radiusChanged)
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)

public:
    explicit WindowBlur(QObject *parent = nullptr);
    ~WindowBlur() override;

    QWindow *window() const;
    void setWindow(QWindow *window);
    QRectF rect() const;
    void setRect(const QRectF &rect);
    qreal radius() const;
    void setRadius(qreal radius);
    bool enabled() const;
    void setEnabled(bool enabled);
    bool available() const;

Q_SIGNALS:
    void windowChanged();
    void rectChanged();
    void radiusChanged();
    void enabledChanged();
    void availableChanged();

private:
    void schedule();
    void apply();
    void readReduced();

    QPointer<QWindow> m_window;
    QRectF m_rect;
    qreal m_radius = 0;
    bool m_enabled = true;
    bool m_pending = false;
    bool m_available = false;
    bool m_reduced = false;
    KConfigWatcher::Ptr m_watcher;
};
