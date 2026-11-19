// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusServiceWatcher>
#include <QFile>
#include <QGuiApplication>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QTimer>

#include <KConfig>
#include <KConfigGroup>

static const char *ApplyQml = R"(
import QtQuick
import org.kernora.system

QtObject {
    id: apply

    required property string wallpaper
    required property string colour
    required property bool dark

    signal finished()

    function paint(): void {
        if (apply.colour !== Appearance.colour) {
            Appearance.setColour(apply.colour, ok => apply.finished());
        } else {
            apply.finished();
        }
    }

    Component.onCompleted: {
        Files.setLiveWallpaper(apply.wallpaper);
        Files.setLockScreenPlugin(apply.wallpaper);
        if (apply.dark !== Appearance.dark) {
            Appearance.setDark(apply.dark, ok => apply.paint());
        } else {
            apply.paint();
        }
    }
}
)";

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("kernora-setup-apply"));

    const QString path = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + QStringLiteral("/kernora-setup-style");
    if (!QFile::exists(path)) {
        return 0;
    }
    KConfig config(path, KConfig::SimpleConfig);
    const KConfigGroup style = config.group(QStringLiteral("Style"));
    static const QRegularExpression plugin(QStringLiteral("^org\\.kernora\\.[a-z0-9]+$"));
    static const QRegularExpression name(QStringLiteral("^[a-z]+(-[a-z]+)*$"));
    QString wallpaper = style.readEntry("wallpaper", QStringLiteral("org.kernora.shapes"));
    QString colour = style.readEntry("colour", QStringLiteral("kernora"));
    if (!plugin.match(wallpaper).hasMatch()) {
        wallpaper = QStringLiteral("org.kernora.shapes");
    }
    if (!name.match(colour).hasMatch()) {
        colour = QStringLiteral("kernora");
    }
    const bool dark = style.readEntry("dark", true);

    QQmlEngine engine;
    QQmlComponent component(&engine);
    QObject *job = nullptr;

    const auto finish = [path]() {
        QFile::remove(path);
        QTimer::singleShot(1000, qApp, &QCoreApplication::quit);
    };

    const auto start = [&]() {
        if (job) {
            return;
        }
        component.setData(ApplyQml, QUrl(QStringLiteral("kernora-setup-apply.qml")));
        job = component.createWithInitialProperties({{QStringLiteral("wallpaper"), wallpaper},
                                                     {QStringLiteral("colour"), colour},
                                                     {QStringLiteral("dark"), dark}});
        if (!job) {
            qWarning("kernora-setup-apply: %s", qPrintable(component.errorString()));
            QCoreApplication::exit(1);
            return;
        }
        QObject::connect(job, SIGNAL(finished()), &app, SLOT(quit()));
        QObject::connect(&app, &QCoreApplication::aboutToQuit, finish);
    };

    const QString shell = QStringLiteral("org.kde.plasmashell");
    QDBusServiceWatcher watcher(shell, QDBusConnection::sessionBus(), QDBusServiceWatcher::WatchForRegistration);
    QObject::connect(&watcher, &QDBusServiceWatcher::serviceRegistered, &app, [&]() {
        QTimer::singleShot(3000, &app, start);
    });
    if (QDBusConnection::sessionBus().interface()->isServiceRegistered(shell)) {
        QTimer::singleShot(3000, &app, start);
    }
    QTimer::singleShot(120000, &app, &QCoreApplication::quit);
    return app.exec();
}
