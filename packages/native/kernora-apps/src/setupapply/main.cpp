// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
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

    Component.onCompleted: {
        Files.setLockScreenPlugin(apply.wallpaper);
        if (apply.colour !== Appearance.colour || apply.dark !== Appearance.dark) {
            Appearance.setStyle(apply.colour, apply.dark, ok => apply.finished());
        } else {
            apply.finished();
        }
    }
}
)";

static void placeWallpaper(const QString &wallpaper)
{
    QDBusMessage message = QDBusMessage::createMethodCall(QStringLiteral("org.kde.plasmashell"), QStringLiteral("/PlasmaShell"),
                                                          QStringLiteral("org.kde.PlasmaShell"), QStringLiteral("evaluateScript"));
    message.setArguments({QStringLiteral("for (const d of desktops()) {"
                                         "  if (d.wallpaperPlugin === '%1') { continue; }"
                                         "  d.currentConfigGroup = ['Wallpaper', '%1', 'General'];"
                                         "  d.writeConfig('IntroAt', String(Date.now()));"
                                         "  d.wallpaperPlugin = '%1';"
                                         "}")
                              .arg(wallpaper)});
    QDBusConnection::sessionBus().call(message, QDBus::Block, 10000);
}

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("kernora-setup-apply"));
    const bool early = app.arguments().contains(QStringLiteral("--early"));

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
    QTimer settle;
    settle.setSingleShot(true);
    settle.setInterval(1000);
    QObject::connect(&settle, &QTimer::timeout, &app, &QCoreApplication::quit);

    const auto finish = [path, wallpaper]() {
        placeWallpaper(wallpaper);
        QFile::remove(path);
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
        QObject::connect(job, SIGNAL(finished()), &settle, SLOT(start()));
    };

    if (early) {
        QTimer::singleShot(0, &app, start);
        QTimer::singleShot(60000, &app, &QCoreApplication::quit);
        return app.exec();
    }

    QObject::connect(&app, &QCoreApplication::aboutToQuit, finish);

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
