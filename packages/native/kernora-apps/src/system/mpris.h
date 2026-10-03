// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <QObject>
#include <QString>
#include <QUrl>
#include <QVariant>
#include <QtQml/qqmlregistration.h>

class MprisPlayer : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString name MEMBER m_name NOTIFY nameChanged)
    Q_PROPERTY(QString identity MEMBER m_identity NOTIFY identityChanged)
    Q_PROPERTY(QString desktopEntry MEMBER m_desktopEntry NOTIFY desktopEntryChanged)

    Q_PROPERTY(bool loaded MEMBER m_loaded NOTIFY loadedChanged)
    Q_PROPERTY(bool playing MEMBER m_playing NOTIFY playingChanged)
    Q_PROPERTY(bool canGoNext MEMBER m_canGoNext NOTIFY canGoNextChanged)
    Q_PROPERTY(bool canGoPrevious MEMBER m_canGoPrevious NOTIFY canGoPreviousChanged)
    Q_PROPERTY(bool canSeek MEMBER m_canSeek NOTIFY canSeekChanged)

    Q_PROPERTY(QString title MEMBER m_title NOTIFY metadataChanged)
    Q_PROPERTY(QString artist MEMBER m_artist NOTIFY metadataChanged)
    Q_PROPERTY(QString album MEMBER m_album NOTIFY metadataChanged)
    Q_PROPERTY(QUrl url MEMBER m_url NOTIFY metadataChanged)
    Q_PROPERTY(QVariant coverImage READ coverImage WRITE setCoverImage NOTIFY metadataChanged)
    Q_PROPERTY(qint64 length MEMBER m_length NOTIFY metadataChanged)
    Q_PROPERTY(QUrl artUrl READ artUrl NOTIFY metadataChanged)
    Q_PROPERTY(qint64 position MEMBER m_position)

public:
    explicit MprisPlayer(QObject *parent = nullptr);
    ~MprisPlayer() override;

    QVariant coverImage() const;
    void setCoverImage(const QVariant &image);
    QUrl artUrl() const;

    Q_INVOKABLE void seeked(qint64 position);

    QString identity() const { return m_identity; }
    QString desktopEntry() const { return m_desktopEntry; }
    bool loaded() const { return m_loaded; }
    bool playing() const { return m_playing; }
    bool canGoNext() const { return m_loaded && m_canGoNext; }
    bool canGoPrevious() const { return m_loaded && m_canGoPrevious; }
    bool canSeek() const { return m_loaded && m_canSeek && m_length > 0; }
    qint64 positionMicroseconds() const { return m_position * 1000; }
    QString playbackStatus() const;
    QVariantMap metadata() const;

Q_SIGNALS:
    void nameChanged();
    void identityChanged();
    void desktopEntryChanged();
    void loadedChanged();
    void playingChanged();
    void canGoNextChanged();
    void canGoPreviousChanged();
    void canSeekChanged();
    void metadataChanged();

    void raiseRequested();
    void quitRequested();
    void playRequested();
    void pauseRequested();
    void stopRequested();
    void nextRequested();
    void previousRequested();
    void seekRequested(qint64 offset);
    void positionRequested(qint64 position);

private:
    void registerService();

    QString m_name;
    QString m_identity;
    QString m_desktopEntry;
    bool m_loaded = false;
    bool m_playing = false;
    bool m_canGoNext = false;
    bool m_canGoPrevious = false;
    bool m_canSeek = true;
    QString m_title;
    QString m_artist;
    QString m_album;
    QUrl m_url;
    QVariant m_coverImage;
    QString m_artPath;
    qint64 m_length = 0;
    qint64 m_position = 0;
    int m_track = 0;

    QString m_service;
    QObject *m_anchor = nullptr;
};
