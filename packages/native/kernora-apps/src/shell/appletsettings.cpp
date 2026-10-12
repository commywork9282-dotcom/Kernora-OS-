// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "appletsettings.h"

#include <Plasma/Applet>
#include <Plasma/Containment>
#include <PlasmaQuick/ConfigView>

#include <QPointer>
#include <QQuickWindow>

namespace
{
QPointer<PlasmaQuick::ConfigView> s_view;
}

AppletSettings::AppletSettings(QObject *parent)
    : QObject(parent)
{
}

bool AppletSettings::open(QObject *object, QQuickItem *item)
{
    auto applet = qobject_cast<Plasma::Applet *>(object);
    if (!applet || !applet->containment() || !applet->hasConfigurationInterface()) {
        return false;
    }

    if (s_view) {
        if (s_view->applet() == applet) {
            s_view->show();
            s_view->requestActivate();
            return true;
        }
        s_view->hide();
    }

    s_view = new PlasmaQuick::ConfigView(applet);
    s_view->init();
    if (item && item->window()) {
        s_view->setTransientParent(item->window());
    }
    s_view->show();
    s_view->requestActivate();
    return true;
}
