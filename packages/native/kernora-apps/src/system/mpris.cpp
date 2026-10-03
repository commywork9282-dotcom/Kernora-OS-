// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "mpris.h"

#include <QCoreApplication>
#include <QDBusAbstractAdaptor>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QSet>
#include <QStandardPaths>
#include <QTimer>

static const QString s_path = QStringLiteral("/org/mpris/MediaPlayer2");

class MprisRootAdaptor : public QDBusAbstractAdaptor
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.mpris.MediaPlayer2")
    Q_PROPERTY(bool CanQuit READ canQuit)
    Q_PROPERTY(bool CanRaise READ canRaise)
    Q_PROPERTY(bool HasTrackList READ hasTrackList)
    Q_PROPERTY(QString Identity READ identity)
    Q_PROPERTY(QString DesktopEntry READ desktopEntry)
    Q_PROPERTY(QStringList SupportedUriSchemes READ supportedUriSchemes)
    Q_PROPERTY(QStringList SupportedMimeTypes READ supportedMimeTypes)

public:
    MprisRootAdaptor(QObject *anchor, MprisPlayer *player)
        : QDBusAbstractAdaptor(anchor)
        , m_player(player)
    {
    }

    bool canQuit() const { return true; }
    bool canRaise() const { return true; }
    bool hasTrackList() const { return false; }
    QString identity() const { return m_player->identity(); }
    QString desktopEntry() const { return m_player->desktopEntry(); }
    QStringList supportedUriSchemes() const { return {QStringLiteral("file")}; }
    QStringList supportedMimeTypes() const { return {}; }

public Q_SLOTS:
    void Raise() { Q_EMIT m_player->raiseRequested(); }
    void Quit() { Q_EMIT m_player->quitRequested(); }

private:
    MprisPlayer *m_player;
};

class MprisPlayerAdaptor : public QDBusAbstractAdaptor
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.mpris.MediaPlayer2.Player")
    Q_PROPERTY(QString PlaybackStatus READ playbackStatus)
    Q_PROPERTY(double Rate READ rate)
    Q_PROPERTY(QVariantMap Metadata READ metadata)
    Q_PROPERTY(double Volume READ volume)
    Q_PROPERTY(qlonglong Position READ position)
    Q_PROPERTY(double MinimumRate READ rate)
    Q_PROPERTY(double MaximumRate READ rate)
    Q_PROPERTY(bool CanGoNext READ canGoNext)
    Q_PROPERTY(bool CanGoPrevious READ canGoPrevious)
    Q_PROPERTY(bool CanPlay READ canPlay)
    Q_PROPERTY(bool CanPause READ canPause)
    Q_PROPERTY(bool CanSeek READ canSeek)
    Q_PROPERTY(bool CanControl READ canControl)

public:
    MprisPlayerAdaptor(QObject *anchor, MprisPlayer *player)
        : QDBusAbstractAdaptor(anchor)
        , m_player(player)
    {
    }

    QString playbackStatus() const { return m_player->playbackStatus(); }
    double rate() const { return 1.0; }
    QVariantMap metadata() const { return m_player->metadata(); }
    double volume() const { return 1.0; }
    qlonglong position() const { return m_player->positionMicroseconds(); }
    bool canGoNext() const { return m_player->canGoNext(); }
    bool canGoPrevious() const { return m_player->canGoPrevious(); }
    bool canPlay() const { return m_player->loaded(); }
    bool canPause() const { return m_player->loaded(); }
    bool canSeek() const { return m_player->canSeek(); }
    bool canControl() const { return true; }

public Q_SLOTS:
    void Next() { Q_EMIT m_player->nextRequested(); }
    void Previous() { Q_EMIT m_player->previousRequested(); }
    void Pause() { Q_EMIT m_player->pauseRequested(); }
    void PlayPause()
    {
        if (m_player->playing()) {
            Q_EMIT m_player->pauseRequested();
        } else {
            Q_EMIT m_player->playRequested();
        }
    }
    void Stop() { Q_EMIT m_player->stopRequested(); }
    void Play() { Q_EMIT m_player->playRequested(); }
    void Seek(qlonglong offset)
    {
        if (m_player->canSeek()) {
            Q_EMIT m_player->seekRequested(offset / 1000);
        }
    }
    void SetPosition(const QDBusObjectPath &trackId, qlonglong position)
    {
        if (m_player->canSeek() && trackId.path() == m_player->metadata().value(QStringLiteral("mpris:trackid")).value<QDBusObjectPath>().path()) {
            Q_EMIT m_player->positionRequested(position / 1000);
        }
    }
    void OpenUri(const QString &) { }

Q_SIGNALS:
    void Seeked(qlonglong position);

private:
    MprisPlayer *m_player;
};

namespace
{
class Notifier : public QObject
{
public:
    explicit Notifier(MprisPlayer *player)
        : QObject(player)
        , m_player(player)
    {
        m_timer.setSingleShot(true);
        m_timer.setInterval(0);
        connect(&m_timer, &QTimer::timeout, this, &Notifier::flush);
    }

    void add(const QStringList &names)
    {
        for (const QString &name : names) {
            m_pending.insert(name);
        }
        m_timer.start();
    }

private:
    void flush()
    {
        QVariantMap changed;
        for (const QString &name : std::as_const(m_pending)) {
            if (name == QLatin1String("PlaybackStatus")) {
                changed.insert(name, m_player->playbackStatus());
            } else if (name == QLatin1String("Metadata")) {
                changed.insert(name, m_player->metadata());
            } else if (name == QLatin1String("CanGoNext")) {
                changed.insert(name, m_player->canGoNext());
            } else if (name == QLatin1String("CanGoPrevious")) {
                changed.insert(name, m_player->canGoPrevious());
            } else if (name == QLatin1String("CanSeek")) {
                changed.insert(name, m_player->canSeek());
            } else if (name == QLatin1String("CanPlay") || name == QLatin1String("CanPause")) {
                changed.insert(name, m_player->loaded());
            }
        }
        m_pending.clear();
        if (changed.isEmpty()) {
            return;
        }
        QDBusMessage signal = QDBusMessage::createSignal(s_path, QStringLiteral("org.freedesktop.DBus.Properties"),
                                                         QStringLiteral("PropertiesChanged"));
        signal << QStringLiteral("org.mpris.MediaPlayer2.Player") << changed << QStringList();
        QDBusConnection::sessionBus().send(signal);
    }

    MprisPlayer *m_player;
    QSet<QString> m_pending;
    QTimer m_timer;
};
}

MprisPlayer::MprisPlayer(QObject *parent)
    : QObject(parent)
{
    auto *notifier = new Notifier(this);
    connect(this, &MprisPlayer::playingChanged, this, [notifier] {
        notifier->add({QStringLiteral("PlaybackStatus")});
    });
    connect(this, &MprisPlayer::loadedChanged, this, [notifier] {
        notifier->add({QStringLiteral("PlaybackStatus"), QStringLiteral("CanPlay"), QStringLiteral("CanPause"),
                       QStringLiteral("CanSeek"), QStringLiteral("CanGoNext"), QStringLiteral("CanGoPrevious"),
                       QStringLiteral("Metadata")});
    });
    connect(this, &MprisPlayer::canGoNextChanged, this, [notifier] {
        notifier->add({QStringLiteral("CanGoNext")});
    });
    connect(this, &MprisPlayer::canGoPreviousChanged, this, [notifier] {
        notifier->add({QStringLiteral("CanGoPrevious")});
    });
    connect(this, &MprisPlayer::canSeekChanged, this, [notifier] {
        notifier->add({QStringLiteral("CanSeek")});
    });
    QUrl lastUrl;
    connect(this, &MprisPlayer::metadataChanged, this, [this, notifier, lastUrl]() mutable {
        if (m_url != lastUrl) {
            lastUrl = m_url;
            ++m_track;
        }
        notifier->add({QStringLiteral("Metadata"), QStringLiteral("CanSeek")});
    });
    QTimer::singleShot(0, this, &MprisPlayer::registerService);
}

MprisPlayer::~MprisPlayer()
{
    if (!m_service.isEmpty()) {
        QDBusConnection::sessionBus().unregisterObject(s_path);
        QDBusConnection::sessionBus().unregisterService(m_service);
    }
    if (!m_artPath.isEmpty()) {
        QFile::remove(m_artPath);
    }
}

void MprisPlayer::registerService()
{
    if (m_name.isEmpty()) {
        m_name = QCoreApplication::applicationName().replace(QLatin1Char('-'), QLatin1Char('_'));
    }
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) {
        return;
    }
    m_anchor = new QObject(this);
    new MprisRootAdaptor(m_anchor, this);
    new MprisPlayerAdaptor(m_anchor, this);
    if (!bus.registerObject(s_path, m_anchor, QDBusConnection::ExportAdaptors)) {
        return;
    }
    QString service = QStringLiteral("org.mpris.MediaPlayer2.") + m_name;
    if (bus.interface()->isServiceRegistered(service)) {
        service += QStringLiteral(".instance") + QString::number(QCoreApplication::applicationPid());
    }
    if (bus.registerService(service)) {
        m_service = service;
    }
}

QString MprisPlayer::playbackStatus() const
{
    if (!m_loaded) {
        return QStringLiteral("Stopped");
    }
    return m_playing ? QStringLiteral("Playing") : QStringLiteral("Paused");
}

QVariantMap MprisPlayer::metadata() const
{
    QVariantMap map;
    if (!m_loaded) {
        return map;
    }
    map.insert(QStringLiteral("mpris:trackid"),
               QVariant::fromValue(QDBusObjectPath(QStringLiteral("/org/kernora/player/track/") + QString::number(m_track))));
    if (m_length > 0) {
        map.insert(QStringLiteral("mpris:length"), qlonglong(m_length) * 1000);
    }
    const QString title = m_title.isEmpty() ? QFileInfo(m_url.path()).completeBaseName() : m_title;
    if (!title.isEmpty()) {
        map.insert(QStringLiteral("xesam:title"), title);
    }
    if (!m_artist.isEmpty()) {
        map.insert(QStringLiteral("xesam:artist"), QStringList{m_artist});
    }
    if (!m_album.isEmpty()) {
        map.insert(QStringLiteral("xesam:album"), m_album);
    }
    if (m_url.isValid()) {
        map.insert(QStringLiteral("xesam:url"), m_url.toString());
    }
    const QUrl art = artUrl();
    if (!art.isEmpty()) {
        map.insert(QStringLiteral("mpris:artUrl"), art.toString());
    }
    return map;
}

QUrl MprisPlayer::artUrl() const
{
    if (!m_loaded) {
        return {};
    }
    if (!m_artPath.isEmpty()) {
        return QUrl::fromLocalFile(m_artPath);
    }
    if (m_url.isLocalFile()) {
        const QDir folder = QFileInfo(m_url.toLocalFile()).dir();
        for (const QString &name : {QStringLiteral("cover.jpg"), QStringLiteral("cover.png"), QStringLiteral("folder.jpg"),
                                    QStringLiteral("Cover.jpg"), QStringLiteral("Folder.jpg"), QStringLiteral("front.jpg")}) {
            if (folder.exists(name)) {
                return QUrl::fromLocalFile(folder.filePath(name));
            }
        }
    }
    return {};
}

QVariant MprisPlayer::coverImage() const
{
    return m_coverImage;
}

void MprisPlayer::setCoverImage(const QVariant &image)
{
    m_coverImage = image;
    if (!m_artPath.isEmpty()) {
        QFile::remove(m_artPath);
        m_artPath.clear();
    }
    const QImage cover = image.value<QImage>();
    if (!cover.isNull()) {
        static int counter = 0;
        const QString folder = QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation);
        const QString path = folder + QStringLiteral("/kernora-player-cover-%1-%2.png")
                                          .arg(QCoreApplication::applicationPid())
                                          .arg(++counter);
        const QImage scaled = cover.width() > 640 || cover.height() > 640
            ? cover.scaled(640, 640, Qt::KeepAspectRatio, Qt::SmoothTransformation)
            : cover;
        if (scaled.save(path, "PNG")) {
            m_artPath = path;
        }
    }
    Q_EMIT metadataChanged();
}

void MprisPlayer::seeked(qint64 position)
{
    m_position = position;
    if (m_anchor) {
        if (auto *adaptor = m_anchor->findChild<MprisPlayerAdaptor *>()) {
            Q_EMIT adaptor->Seeked(position * 1000);
        }
    }
}

#include "mpris.moc"
