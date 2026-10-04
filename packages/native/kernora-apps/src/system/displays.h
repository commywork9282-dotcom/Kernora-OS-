// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <QAbstractListModel>
#include <QtQml/qqmlregistration.h>

#include <KScreen/Config>

class Displays : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        LabelRole,
        EnabledRole,
        PrimaryRole,
        ModesRole,
        ResolutionsRole,
        CurrentModeRole,
        ResolutionRole,
        RefreshRatesRole,
        RefreshRole,
        ScaleRole,
        RotationRole,
        PreferredResolutionRole,
        GeometryRole,
        MirrorSourceRole,
        CapabilitiesRole,
        OverscanRole,
        VrrRole,
        RgbRangeRole,
        HdrRole,
        ColorProfileRole,
    };
    Q_ENUM(Roles)

    explicit Displays(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool ready() const { return m_config != nullptr; }
    int count() const { return rowCount(); }

    Q_INVOKABLE void snapshot();
    Q_INVOKABLE void revert();
    Q_INVOKABLE void setResolution(int row, const QString &resolution);
    Q_INVOKABLE void setRefresh(int row, double refresh);
    Q_INVOKABLE void setScale(int row, double scale);
    Q_INVOKABLE void setRotation(int row, int degrees);
    Q_INVOKABLE void setEnabled(int row, bool enabled);
    Q_INVOKABLE void setPrimary(int row);
    Q_INVOKABLE void setPosition(int row, int x, int y);
    Q_INVOKABLE void setMirror(int row, int sourceRow);
    Q_INVOKABLE void setOverscan(int row, int percent);
    Q_INVOKABLE void setVrr(int row, int policy);
    Q_INVOKABLE void setRgbRange(int row, int range);
    Q_INVOKABLE void setHdr(int row, bool enabled);
    Q_INVOKABLE void setColorProfile(int row, const QString &path);

Q_SIGNALS:
    void readyChanged();
    void countChanged();
    void applied(bool ok);

private:
    void load();
    void apply();
    KScreen::OutputPtr output(int row) const;
    KScreen::ModePtr bestMode(const KScreen::OutputPtr &output, const QSize &size, double refresh) const;
    QRect logicalGeometry(const KScreen::OutputPtr &output) const;
    int mirrorSourceId(const KScreen::OutputPtr &output) const;
    void normalizePositions();

    KScreen::ConfigPtr m_config;
    KScreen::ConfigPtr m_saved;
    QList<int> m_ids;
};
