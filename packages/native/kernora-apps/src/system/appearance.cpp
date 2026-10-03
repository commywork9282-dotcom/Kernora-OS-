// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "appearance.h"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDir>
#include <QFile>
#include <QJSEngine>
#include <QProcess>
#include <QSaveFile>
#include <QStandardPaths>

#include <KConfig>
#include <KConfigGroup>
#include <KSharedConfig>

#include <memory>

struct Appearance::Switch {
    QList<QPair<QString, QString>> steps;
    QJSValue callback;
    bool ok = true;
};

Appearance::Appearance(QObject *parent)
    : QObject(parent)
    , m_watcher(KConfigWatcher::create(KSharedConfig::openConfig(QStringLiteral("kdeglobals"))))
{
    connect(m_watcher.data(), &KConfigWatcher::configChanged, this, [this](const KConfigGroup &group) {
        if (group.name() == QLatin1String("General")) {
            Q_EMIT darkChanged();
        }
    });
}

bool Appearance::dark() const
{
    const KConfigGroup general(KSharedConfig::openConfig(QStringLiteral("kdeglobals")), QStringLiteral("General"));
    return !general.readEntry("ColorScheme", QStringLiteral("KernoraDark")).endsWith(QLatin1String("Light"));
}

QString Appearance::generation() const
{
    auto config = KSharedConfig::openConfig(QStringLiteral("kernorarc"));
    config->reparseConfiguration();
    const QString value = KConfigGroup(config, QStringLiteral("Style")).readEntry("generation", QStringLiteral("md3"));
    return value == QLatin1String("md1") || value == QLatin1String("md2") ? value : QStringLiteral("md3");
}

void Appearance::writeTerminalColours(bool dark) const
{
    const QString source = QStandardPaths::locate(QStandardPaths::GenericDataLocation,
                                                  QStringLiteral("kernora/terminal/%1.toml").arg(dark ? QStringLiteral("dark") : QStringLiteral("light")));
    if (source.isEmpty()) {
        return;
    }
    QFile in(source);
    if (!in.open(QIODevice::ReadOnly)) {
        return;
    }
    const QString folder = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + QStringLiteral("/alacritty");
    QDir().mkpath(folder);
    QSaveFile out(folder + QStringLiteral("/kernora-colors.toml"));
    if (out.open(QIODevice::WriteOnly)) {
        out.write(in.readAll());
        out.commit();
    }
}

void Appearance::setDark(bool enable, const QJSValue &callback)
{
    apply(generation(), enable, callback);
}

void Appearance::setGeneration(const QString &generation, const QJSValue &callback)
{
    apply(generation, dark(), callback);
}

void Appearance::apply(const QString &requested, bool enable, const QJSValue &callback)
{
    if (m_busy) {
        return;
    }
    m_busy = true;
    Q_EMIT busyChanged();

    const QString generation = requested == QLatin1String("md1") || requested == QLatin1String("md2") ? requested : QStringLiteral("md3");
    const bool generationChanges = generation != this->generation();
    const QString lower = generation == QLatin1String("md3") ? QString() : QLatin1Char('-') + generation;
    const QString upper = generation == QLatin1String("md3") ? QString() : generation.toUpper();

    auto kernora = KSharedConfig::openConfig(QStringLiteral("kernorarc"));
    KConfigGroup style(kernora, QStringLiteral("Style"));
    style.writeEntry("generation", generation);
    kernora->sync();

    const QString kvantumFolder = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + QStringLiteral("/Kvantum");
    QDir().mkpath(kvantumFolder);
    KConfig kvantum(kvantumFolder + QStringLiteral("/kvantum.kvconfig"), KConfig::SimpleConfig);
    KConfigGroup kvantumGeneral(&kvantum, QStringLiteral("General"));
    kvantumGeneral.writeEntry("theme", QString(QStringLiteral("Kernora") + upper));
    kvantum.sync();

    auto globals = KSharedConfig::openConfig(QStringLiteral("kdeglobals"));
    KConfigGroup kde(globals, QStringLiteral("KDE"));
    if (generationChanges) {
        kde.writeEntry("widgetStyle", enable ? QStringLiteral("kvantum") : QStringLiteral("kvantum-dark"), KConfig::Notify);
        globals->sync();
    }
    kde.writeEntry("widgetStyle", enable ? QStringLiteral("kvantum-dark") : QStringLiteral("kvantum"), KConfig::Notify);
    globals->sync();

    auto kwin = KSharedConfig::openConfig(QStringLiteral("kwinrc"));
    KConfigGroup decoration(kwin, QStringLiteral("org.kde.kdecoration2"));
    decoration.writeEntry("theme", QString(QStringLiteral("__aurorae__svg__kernora") + lower + (enable ? QString() : QStringLiteral("-light"))),
                          KConfig::Notify);
    kwin->sync();

    writeTerminalColours(enable);

    QDBusMessage panels = QDBusMessage::createMethodCall(QStringLiteral("org.kde.plasmashell"), QStringLiteral("/PlasmaShell"),
                                                         QStringLiteral("org.kde.PlasmaShell"), QStringLiteral("evaluateScript"));
    panels.setArguments({QStringLiteral("panels().forEach(function (panel) { panel.floating = %1; });")
                             .arg(generation == QLatin1String("md1") ? QStringLiteral("false") : QStringLiteral("true"))});
    QDBusConnection::sessionBus().send(panels);

    auto state = std::make_shared<Switch>();
    state->steps = {
        {QStringLiteral("plasma-apply-desktoptheme"), QStringLiteral("kernora") + lower + (enable ? QString() : QStringLiteral("-light"))},
        {QStringLiteral("plasma-apply-colorscheme"), QStringLiteral("Kernora") + upper + (enable ? QStringLiteral("Dark") : QStringLiteral("Light"))},
    };
    state->callback = callback;
    if (generationChanges) {
        Q_EMIT generationChanged();
    }
    runStep(state, 0);
}

void Appearance::runStep(const std::shared_ptr<Switch> &state, int index)
{
    if (index >= state->steps.size()) {
        QDBusConnection::sessionBus().send(
            QDBusMessage::createMethodCall(QStringLiteral("org.kde.KWin"), QStringLiteral("/KWin"), QStringLiteral("org.kde.KWin"), QStringLiteral("reconfigure")));
        QDBusMessage style = QDBusMessage::createSignal(QStringLiteral("/KGlobalSettings"), QStringLiteral("org.kde.KGlobalSettings"), QStringLiteral("notifyChange"));
        style.setArguments({2, 0});
        QDBusConnection::sessionBus().send(style);
        m_busy = false;
        Q_EMIT busyChanged();
        Q_EMIT darkChanged();
        if (state->callback.isCallable()) {
            QJSValue function = state->callback;
            function.call({QJSValue(state->ok)});
        }
        return;
    }
    auto *process = new QProcess(this);
    auto done = [this, process, state, index](bool success) {
        if (!success) {
            state->ok = false;
        }
        process->deleteLater();
        runStep(state, index + 1);
    };
    connect(process, &QProcess::finished, this, [done](int code, QProcess::ExitStatus status) {
        done(code == 0 && status == QProcess::NormalExit);
    });
    connect(process, &QProcess::errorOccurred, this, [done](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart) {
            done(false);
        }
    });
    process->start(state->steps.at(index).first, {state->steps.at(index).second});
}
