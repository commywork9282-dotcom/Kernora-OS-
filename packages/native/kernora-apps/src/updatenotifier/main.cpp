// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "avatarsync.h"
#include "greetersync.h"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDateTime>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocale>
#include <QNetworkInformation>
#include <QPointer>
#include <QProcess>
#include <QProcessEnvironment>
#include <QStandardPaths>
#include <QTimer>

#include <KAboutData>
#include <KConfig>
#include <KConfigGroup>
#include <KDBusService>
#include <KLocalizedString>
#include <KNotification>
#include <KSharedConfig>

#include <PackageKit/Daemon>
#include <PackageKit/Transaction>

#include <algorithm>
#include <memory>

using PackageKit::Daemon;
using PackageKit::Transaction;

static constexpr int FirstCheck = 2 * 60;
static constexpr int CheckInterval = 6 * 60 * 60;
static constexpr int RefreshAge = 24 * 60 * 60;
static constexpr int RestartInterval = 10 * 60;
static constexpr int DriverInterval = 60;
static constexpr int WhatsNewDelay = 6;
static constexpr qint64 PanicAge = 3 * 24 * 60 * 60;

static QString readFile(const QString &path)
{
    QFile file(path);
    return file.open(QIODevice::ReadOnly) ? QString::fromUtf8(file.readAll()).trimmed() : QString();
}

static bool liveSession()
{
    return readFile(QStringLiteral("/proc/cmdline")).split(QLatin1Char(' ')).contains(QStringLiteral("boot=live"));
}

static bool metered()
{
    if (!QNetworkInformation::loadBackendByFeatures(QNetworkInformation::Feature::Metered)) {
        return false;
    }
    return QNetworkInformation::instance()->isMetered();
}

static void openUpdates(KNotification *notification)
{
    QProcessEnvironment environment = QProcessEnvironment::systemEnvironment();
    const QString token = notification->xdgActivationToken();
    if (!token.isEmpty()) {
        environment.insert(QStringLiteral("XDG_ACTIVATION_TOKEN"), token);
    }
    QProcess process;
    process.setProgram(QStringLiteral("kernora-settings"));
    process.setArguments({QStringLiteral("kcm_updates")});
    process.setProcessEnvironment(environment);
    process.startDetached();
}

static QString latestRelease()
{
    QFile file(QStandardPaths::locate(QStandardPaths::GenericDataLocation, QStringLiteral("kernora/whatsnew.json")));
    if (!file.open(QIODevice::ReadOnly)) {
        return QString();
    }
    return QJsonDocument::fromJson(file.readAll()).array().at(0).toObject().value(QStringLiteral("id")).toString();
}

static void showWhatsNew()
{
    const QString latest = latestRelease();
    if (latest.isEmpty()) {
        return;
    }
    KSharedConfig::Ptr welcome = KSharedConfig::openConfig(QStringLiteral("kernora-welcomerc"));
    KConfigGroup notes = welcome->group(QStringLiteral("WhatsNew"));
    if (notes.readEntry("Seen", QString()) == latest) {
        return;
    }
    if (welcome->group(QStringLiteral("General")).readEntry("ShowOnLogin", true)) {
        notes.writeEntry("Seen", latest);
        notes.sync();
        return;
    }
    QTimer::singleShot(WhatsNewDelay * 1000, qApp, []() {
        QProcess::startDetached(QStringLiteral("kernora-welcome"), {QStringLiteral("--whats-new")});
    });
}

static bool showKernelPanic()
{
    KConfig panic(QStringLiteral("/var/lib/kernora/kernel-panic.conf"), KConfig::SimpleConfig);
    const KConfigGroup record(&panic, QStringLiteral("Panic"));
    const QString id = record.readEntry("id", QString());
    if (id.isEmpty()) {
        return false;
    }
    KSharedConfig::Ptr welcome = KSharedConfig::openConfig(QStringLiteral("kernora-welcomerc"));
    KConfigGroup seen = welcome->group(QStringLiteral("KernelPanic"));
    if (seen.readEntry("Seen", QString()) == id) {
        return false;
    }
    seen.writeEntry("Seen", id);
    seen.sync();
    if (QDateTime::currentSecsSinceEpoch() - record.readEntry("time", qint64(0)) > PanicAge) {
        return false;
    }
    QTimer::singleShot(WhatsNewDelay * 1000, qApp, []() {
        QProcess::startDetached(QStringLiteral("kernora-welcome"), {QStringLiteral("--kernel-panic")});
    });
    return true;
}

class Notifier : public QObject
{
public:
    Notifier()
        : m_state(KSharedConfig::openStateConfig()->group(QStringLiteral("Updates")))
    {
        Daemon::global()->setHints({QStringLiteral("background=true"), QStringLiteral("interactive=false"),
                                    QStringLiteral("locale=%1.UTF-8").arg(QLocale::system().name())});
        m_check.setSingleShot(true);
        connect(&m_check, &QTimer::timeout, this, &Notifier::check);
        connect(Daemon::global(), &Daemon::updatesChanged, this, [this]() {
            schedule(60);
        });
        connect(&m_restart, &QTimer::timeout, this, &Notifier::checkRestart);
        m_restart.start(RestartInterval * 1000);
        connect(&m_driver, &QTimer::timeout, this, &Notifier::checkDriver);
        m_driver.start(DriverInterval * 1000);
        schedule(FirstCheck);
        checkRestart();
        checkDriver();
    }

private:
    void schedule(int seconds)
    {
        if (!m_busy) {
            m_check.start(seconds * 1000);
        }
    }

    qint64 lastRefresh() const
    {
        const QFileInfo stamp(QStringLiteral("/var/lib/apt/periodic/update-success-stamp"));
        const qint64 apt = stamp.exists() ? stamp.lastModified().toSecsSinceEpoch() : 0;
        return std::max(apt, m_state.readEntry("LastRefresh", qint64(0)));
    }

    void check()
    {
        if (m_busy) {
            return;
        }
        m_busy = true;
        const qint64 now = QDateTime::currentSecsSinceEpoch();
        if (now - lastRefresh() < RefreshAge || metered()) {
            fetch();
            return;
        }
        Transaction *refresh = Daemon::refreshCache(false);
        connect(refresh, &Transaction::finished, this, [this, now](Transaction::Exit exit) {
            if (exit == Transaction::ExitSuccess) {
                m_state.writeEntry("LastRefresh", now);
                m_state.sync();
            }
            fetch();
        });
    }

    void fetch()
    {
        auto ids = std::make_shared<QStringList>();
        auto security = std::make_shared<int>(0);
        Transaction *list = Daemon::getUpdates();
        connect(list, &Transaction::package, this, [ids, security](Transaction::Info info, const QString &id, const QString &) {
            if (info == Transaction::InfoBlocked) {
                return;
            }
            ids->append(id);
            if (info == Transaction::InfoSecurity || Daemon::packageData(id).contains(QLatin1String("security"))) {
                *security += 1;
            }
        });
        connect(list, &Transaction::finished, this, [this, ids, security](Transaction::Exit exit) {
            m_busy = false;
            schedule(CheckInterval);
            if (exit == Transaction::ExitSuccess) {
                announce(*ids, *security);
            }
        });
    }

    void announce(const QStringList &ids, int security)
    {
        const QStringList notified = m_state.readEntry("Notified", QStringList());
        if (ids.isEmpty()) {
            if (m_updates) {
                m_updates->close();
            }
            m_state.writeEntry("Notified", QStringList());
            m_state.sync();
            return;
        }
        const bool fresh = std::any_of(ids.cbegin(), ids.cend(), [&notified](const QString &id) {
            return !notified.contains(id);
        });
        if (!fresh) {
            return;
        }
        m_state.writeEntry("Notified", ids);
        m_state.sync();

        if (m_updates) {
            m_updates->close();
        }
        m_updates = new KNotification(QStringLiteral("updatesAvailable"));
        m_updates->setComponentName(QStringLiteral("kernora-updates"));
        m_updates->setIconName(QStringLiteral("system-software-update"));
        m_updates->setTitle(i18n("Updates are available"));
        m_updates->setText(security > 0
                               ? i18np("%1 update is ready to install, with security fixes.",
                                       "%1 updates are ready to install, among them security fixes.", int(ids.size()))
                               : i18np("%1 update is ready to install.", "%1 updates are ready to install.", int(ids.size())));
        KNotification *notification = m_updates;
        connect(m_updates->addDefaultAction(i18n("Open Updates")), &KNotificationAction::activated, this, [notification]() {
            openUpdates(notification);
        });
        connect(m_updates->addAction(i18n("View")), &KNotificationAction::activated, this, [notification]() {
            openUpdates(notification);
        });
        m_updates->sendEvent();
    }

    void checkRestart()
    {
        if (!QFileInfo::exists(QStringLiteral("/run/reboot-required"))) {
            return;
        }
        const QString boot = readFile(QStringLiteral("/proc/sys/kernel/random/boot_id"));
        if (boot.isEmpty() || m_state.readEntry("RestartNotified", QString()) == boot) {
            return;
        }
        m_state.writeEntry("RestartNotified", boot);
        m_state.sync();

        auto *notification = new KNotification(QStringLiteral("restartNeeded"));
        notification->setComponentName(QStringLiteral("kernora-updates"));
        notification->setIconName(QStringLiteral("system-reboot"));
        notification->setTitle(i18n("Restart to finish updating"));
        notification->setText(i18n("Updates were installed. They take effect after a restart."));
        connect(notification->addAction(i18n("Restart")), &KNotificationAction::activated, this, []() {
            QDBusConnection::sessionBus().asyncCall(QDBusMessage::createMethodCall(QStringLiteral("org.kde.LogoutPrompt"),
                                                                                  QStringLiteral("/LogoutPrompt"),
                                                                                  QStringLiteral("org.kde.LogoutPrompt"),
                                                                                  QStringLiteral("promptReboot")));
        });
        notification->sendEvent();
    }

    void checkDriver()
    {
        const QString boot = readFile(QStringLiteral("/proc/sys/kernel/random/boot_id"));
        if (boot.isEmpty()) {
            return;
        }
        const QString readyFile = QStringLiteral("/run/kernora-driver-ready");
        QString status;
        QString name;
        if (QFileInfo::exists(readyFile)) {
            status = QStringLiteral("ready");
            name = readFile(readyFile);
        } else {
            const QStringList lines = readFile(QStringLiteral("/var/lib/kernora/drivers/state")).split(QLatin1Char('\n'));
            for (const QString &line : lines) {
                if (line.startsWith(QLatin1String("status="))) {
                    status = line.mid(7);
                } else if (line.startsWith(QLatin1String("name="))) {
                    name = line.mid(5);
                }
            }
        }
        if (status != QLatin1String("ready") && status != QLatin1String("installing")) {
            return;
        }
        const QString key = status == QLatin1String("ready") ? QStringLiteral("DriverReadyNotified") : QStringLiteral("DriverInstallingNotified");
        if (m_state.readEntry(key, QString()) == boot) {
            return;
        }
        m_state.writeEntry(key, boot);
        m_state.sync();

        const QString card = name.isEmpty() ? i18n("your NVIDIA graphics card") : name;
        if (status == QLatin1String("installing")) {
            auto *notification = new KNotification(QStringLiteral("driverInstalling"));
            notification->setComponentName(QStringLiteral("kernora-updates"));
            notification->setIconName(QStringLiteral("cpu"));
            notification->setTitle(i18n("Installing the graphics driver"));
            notification->setText(i18n("Kernora is installing the driver for %1. It takes a few minutes, and you can keep working.", card));
            notification->sendEvent();
            return;
        }
        auto *notification = new KNotification(QStringLiteral("driverReady"));
        notification->setComponentName(QStringLiteral("kernora-updates"));
        notification->setIconName(QStringLiteral("system-reboot"));
        notification->setTitle(i18n("Restart to use your graphics card"));
        notification->setText(i18n("The driver for %1 is installed. It starts working after a restart.", card));
        connect(notification->addAction(i18n("Restart")), &KNotificationAction::activated, this, []() {
            QDBusConnection::sessionBus().asyncCall(QDBusMessage::createMethodCall(QStringLiteral("org.kde.LogoutPrompt"),
                                                                                  QStringLiteral("/LogoutPrompt"),
                                                                                  QStringLiteral("org.kde.LogoutPrompt"),
                                                                                  QStringLiteral("promptReboot")));
        });
        notification->sendEvent();
    }

    KConfigGroup m_state;
    QTimer m_check;
    QTimer m_restart;
    QTimer m_driver;
    QPointer<KNotification> m_updates;
    bool m_busy = false;
};

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setQuitOnLastWindowClosed(false);
    KLocalizedString::setApplicationDomain(TRANSLATION_DOMAIN);

    KAboutData about(QStringLiteral("kernora-update-notifier"), i18n("Update notifications"), QStringLiteral(KERNORA_APPS_VERSION));
    about.setDesktopFileName(QStringLiteral("org.kernora.settings"));
    about.setOrganizationDomain("kernora.invalid");
    KAboutData::setApplicationData(about);

    if (liveSession() || !QFileInfo::exists(QStringLiteral("/usr/libexec/packagekitd"))) {
        return 0;
    }

    KDBusService service(KDBusService::Unique);
    if (!showKernelPanic()) {
        showWhatsNew();
    }
    Notifier notifier;
    GreeterSync greeter;
    AvatarSync avatar;
    return app.exec();
}
