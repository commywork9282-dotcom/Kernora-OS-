// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "displays.h"

#include <KScreen/ConfigMonitor>
#include <KScreen/EDID>
#include <KScreen/GetConfigOperation>
#include <KScreen/Mode>
#include <KScreen/Output>
#include <KScreen/SetConfigOperation>

#include <KLocalizedString>

#include <algorithm>
#include <climits>
#include <cmath>

Displays::Displays(QObject *parent)
    : QAbstractListModel(parent)
{
    load();
}

void Displays::load()
{
    auto *operation = new KScreen::GetConfigOperation();
    connect(operation, &KScreen::ConfigOperation::finished, this, [this](KScreen::ConfigOperation *op) {
        if (op->hasError()) {
            return;
        }
        beginResetModel();
        m_config = qobject_cast<KScreen::GetConfigOperation *>(op)->config();
        m_ids.clear();
        for (const auto &output : m_config->outputs()) {
            if (output->isConnected()) {
                m_ids.append(output->id());
            }
        }
        std::sort(m_ids.begin(), m_ids.end());
        endResetModel();
        KScreen::ConfigMonitor::instance()->addConfig(m_config);
        connect(KScreen::ConfigMonitor::instance(), &KScreen::ConfigMonitor::configurationChanged, this, [this]() {
            if (rowCount() > 0) {
                Q_EMIT dataChanged(index(0), index(rowCount() - 1));
            }
        });
        Q_EMIT readyChanged();
        Q_EMIT countChanged();
    });
}

KScreen::OutputPtr Displays::output(int row) const
{
    if (!m_config || row < 0 || row >= m_ids.size()) {
        return {};
    }
    return m_config->output(m_ids.at(row));
}

int Displays::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_ids.size();
}

QHash<int, QByteArray> Displays::roleNames() const
{
    return {
        {NameRole, "name"},
        {LabelRole, "label"},
        {EnabledRole, "enabled"},
        {PrimaryRole, "primary"},
        {ModesRole, "modes"},
        {ResolutionsRole, "resolutions"},
        {CurrentModeRole, "currentMode"},
        {ResolutionRole, "resolution"},
        {RefreshRatesRole, "refreshRates"},
        {RefreshRole, "refresh"},
        {ScaleRole, "scale"},
        {RotationRole, "rotation"},
        {PreferredResolutionRole, "preferredResolution"},
        {GeometryRole, "geometry"},
        {MirrorSourceRole, "mirrorSource"},
        {CapabilitiesRole, "capabilities"},
        {OverscanRole, "overscan"},
        {VrrRole, "vrr"},
        {RgbRangeRole, "rgbRange"},
        {HdrRole, "hdr"},
        {ColorProfileRole, "colorProfile"},
    };
}

static QString sizeLabel(const QSize &size)
{
    return QStringLiteral("%1 × %2").arg(size.width()).arg(size.height());
}

static int rotationDegrees(KScreen::Output::Rotation rotation)
{
    switch (rotation) {
    case KScreen::Output::Left:
        return 90;
    case KScreen::Output::Inverted:
        return 180;
    case KScreen::Output::Right:
        return 270;
    default:
        return 0;
    }
}

QVariant Displays::data(const QModelIndex &index, int role) const
{
    const auto out = output(index.row());
    if (!out) {
        return {};
    }
    const auto mode = out->currentMode();
    switch (role) {
    case NameRole:
        return out->name();
    case LabelRole: {
        QString label;
        if (out->edid() && out->edid()->isValid()) {
            label = QStringLiteral("%1 %2").arg(out->edid()->vendor(), out->edid()->name()).simplified();
        }
        if (label.isEmpty() || out->type() == KScreen::Output::Panel) {
            label = out->type() == KScreen::Output::Panel ? i18n("Built-in display") : out->name();
        }
        return label;
    }
    case EnabledRole:
        return out->isEnabled();
    case PrimaryRole:
        return out->isPrimary();
    case ModesRole: {
        QVariantList modes;
        for (const auto &m : out->modes()) {
            modes.append(QVariantMap{{QStringLiteral("id"), m->id()},
                                     {QStringLiteral("width"), m->size().width()},
                                     {QStringLiteral("height"), m->size().height()},
                                     {QStringLiteral("refresh"), m->refreshRate()}});
        }
        return modes;
    }
    case ResolutionsRole: {
        QList<QSize> sizes;
        for (const auto &m : out->modes()) {
            if (!sizes.contains(m->size())) {
                sizes.append(m->size());
            }
        }
        std::sort(sizes.begin(), sizes.end(), [](const QSize &a, const QSize &b) {
            return a.width() * a.height() > b.width() * b.height();
        });
        QStringList labels;
        for (const QSize &size : sizes) {
            labels.append(sizeLabel(size));
        }
        return labels;
    }
    case CurrentModeRole:
        return mode ? mode->id() : QString();
    case ResolutionRole:
        return mode ? sizeLabel(mode->size()) : QString();
    case RefreshRatesRole: {
        QList<double> rates;
        if (mode) {
            for (const auto &m : out->modes()) {
                const double rate = std::round(m->refreshRate());
                if (m->size() == mode->size() && !rates.contains(rate)) {
                    rates.append(rate);
                }
            }
        }
        std::sort(rates.begin(), rates.end(), std::greater<>());
        QVariantList list;
        for (double rate : rates) {
            list.append(rate);
        }
        return list;
    }
    case RefreshRole:
        return mode ? std::round(mode->refreshRate()) : 0.0;
    case ScaleRole:
        return out->scale();
    case RotationRole:
        return rotationDegrees(out->rotation());
    case PreferredResolutionRole: {
        const auto preferred = out->preferredMode();
        return preferred ? sizeLabel(preferred->size()) : QString();
    }
    case GeometryRole: {
        const QRect geometry = logicalGeometry(out);
        return QVariantMap{{QStringLiteral("x"), geometry.x()},
                           {QStringLiteral("y"), geometry.y()},
                           {QStringLiteral("width"), geometry.width()},
                           {QStringLiteral("height"), geometry.height()}};
    }
    case MirrorSourceRole:
        return m_ids.indexOf(mirrorSourceId(out));
    case CapabilitiesRole: {
        const auto capabilities = out->capabilities();
        return QVariantMap{{QStringLiteral("overscan"), capabilities.testFlag(KScreen::Output::Capability::Overscan)},
                           {QStringLiteral("vrr"), capabilities.testFlag(KScreen::Output::Capability::Vrr)},
                           {QStringLiteral("rgbRange"), capabilities.testFlag(KScreen::Output::Capability::RgbRange)},
                           {QStringLiteral("hdr"), capabilities.testFlag(KScreen::Output::Capability::HighDynamicRange)},
                           {QStringLiteral("colorProfile"), capabilities.testFlag(KScreen::Output::Capability::IccProfile)}};
    }
    case OverscanRole:
        return int(out->overscan());
    case VrrRole:
        return int(out->vrrPolicy());
    case RgbRangeRole:
        return int(out->rgbRange());
    case HdrRole:
        return out->isHdrEnabled();
    case ColorProfileRole:
        return out->iccProfilePath();
    }
    return {};
}

QRect Displays::logicalGeometry(const KScreen::OutputPtr &out) const
{
    QSizeF size = out->explicitLogicalSize();
    if (!size.isValid() || size.isEmpty()) {
        const auto mode = out->currentMode();
        QSizeF modeSize = mode ? QSizeF(mode->size()) : QSizeF();
        if (out->rotation() == KScreen::Output::Left || out->rotation() == KScreen::Output::Right) {
            modeSize.transpose();
        }
        size = modeSize / (out->scale() > 0 ? out->scale() : 1.0);
    }
    return QRect(out->pos(), size.toSize());
}

int Displays::mirrorSourceId(const KScreen::OutputPtr &out) const
{
    if (out->replicationSource() != 0) {
        return out->replicationSource();
    }
    if (!out->isEnabled()) {
        return 0;
    }
    for (int id : std::as_const(m_ids)) {
        const auto other = m_config->output(id);
        if (other->id() == out->id() || !other->isEnabled() || other->pos() != out->pos() || other->replicationSource() != 0) {
            continue;
        }
        const bool otherFirst = other->priority() < out->priority() || (other->priority() == out->priority() && other->id() < out->id());
        if (otherFirst) {
            return other->id();
        }
    }
    return 0;
}

void Displays::normalizePositions()
{
    int left = INT_MAX;
    int top = INT_MAX;
    for (int id : std::as_const(m_ids)) {
        const auto out = m_config->output(id);
        if (out->isEnabled() && mirrorSourceId(out) == 0) {
            left = std::min(left, out->pos().x());
            top = std::min(top, out->pos().y());
        }
    }
    if (left == INT_MAX) {
        return;
    }
    for (int id : std::as_const(m_ids)) {
        const auto out = m_config->output(id);
        out->setPos(out->pos() - QPoint(left, top));
    }
}

void Displays::setPosition(int row, int x, int y)
{
    auto out = output(row);
    if (!out) {
        return;
    }
    QList<KScreen::OutputPtr> mirrors;
    for (int id : std::as_const(m_ids)) {
        const auto mirror = m_config->output(id);
        if (mirrorSourceId(mirror) == out->id()) {
            mirrors.append(mirror);
        }
    }
    out->setPos(QPoint(x, y));
    for (const auto &mirror : std::as_const(mirrors)) {
        mirror->setPos(out->pos());
    }
    normalizePositions();
    apply();
}

void Displays::setMirror(int row, int sourceRow)
{
    auto out = output(row);
    if (!out) {
        return;
    }
    const auto source = output(sourceRow);
    if (source && source->id() != out->id()) {
        out->setReplicationSource(source->id());
        out->setPos(source->pos());
    } else {
        out->setReplicationSource(0);
        int right = 0;
        for (int id : std::as_const(m_ids)) {
            const auto other = m_config->output(id);
            if (other->id() != out->id() && other->isEnabled() && mirrorSourceId(other) == 0) {
                right = std::max(right, logicalGeometry(other).right() + 1);
            }
        }
        out->setPos(QPoint(right, 0));
    }
    normalizePositions();
    apply();
}

void Displays::setOverscan(int row, int percent)
{
    if (auto out = output(row)) {
        out->setOverscan(uint32_t(std::clamp(percent, 0, 100)));
        apply();
    }
}

void Displays::setVrr(int row, int policy)
{
    if (auto out = output(row)) {
        out->setVrrPolicy(static_cast<KScreen::Output::VrrPolicy>(std::clamp(policy, 0, 2)));
        apply();
    }
}

void Displays::setRgbRange(int row, int range)
{
    if (auto out = output(row)) {
        out->setRgbRange(static_cast<KScreen::Output::RgbRange>(std::clamp(range, 0, 2)));
        apply();
    }
}

void Displays::setHdr(int row, bool enabled)
{
    if (auto out = output(row)) {
        out->setHdrEnabled(enabled);
        apply();
    }
}

void Displays::setColorProfile(int row, const QString &path)
{
    if (auto out = output(row)) {
        out->setIccProfilePath(path);
        apply();
    }
}

KScreen::ModePtr Displays::bestMode(const KScreen::OutputPtr &out, const QSize &size, double refresh) const
{
    KScreen::ModePtr best;
    for (const auto &m : out->modes()) {
        if (m->size() != size) {
            continue;
        }
        if (!best) {
            best = m;
            continue;
        }
        if (refresh > 0) {
            if (std::abs(m->refreshRate() - refresh) < std::abs(best->refreshRate() - refresh)) {
                best = m;
            }
        } else if (m->refreshRate() > best->refreshRate()) {
            best = m;
        }
    }
    return best;
}

void Displays::snapshot()
{
    if (m_config) {
        m_saved = m_config->clone();
    }
}

void Displays::revert()
{
    if (!m_saved) {
        return;
    }
    for (const auto &saved : m_saved->outputs()) {
        auto current = m_config->output(saved->id());
        if (!current) {
            continue;
        }
        current->setEnabled(saved->isEnabled());
        current->setCurrentModeId(saved->currentModeId());
        current->setScale(saved->scale());
        current->setRotation(saved->rotation());
        current->setPos(saved->pos());
        current->setPriority(saved->priority());
        current->setReplicationSource(saved->replicationSource());
    }
    m_saved.reset();
    apply();
}

void Displays::apply()
{
    if (!m_config) {
        return;
    }
    auto *operation = new KScreen::SetConfigOperation(m_config);
    connect(operation, &KScreen::ConfigOperation::finished, this, [this](KScreen::ConfigOperation *op) {
        Q_EMIT applied(!op->hasError());
        if (rowCount() > 0) {
            Q_EMIT dataChanged(index(0), index(rowCount() - 1));
        }
    });
}

void Displays::setResolution(int row, const QString &resolution)
{
    auto out = output(row);
    if (!out) {
        return;
    }
    const QStringList parts = resolution.split(QStringLiteral(" × "));
    if (parts.size() != 2) {
        return;
    }
    const QSize size(parts.at(0).toInt(), parts.at(1).toInt());
    const auto current = out->currentMode();
    const auto mode = bestMode(out, size, current ? current->refreshRate() : 0);
    if (mode) {
        out->setCurrentModeId(mode->id());
        apply();
    }
}

void Displays::setRefresh(int row, double refresh)
{
    auto out = output(row);
    if (!out || !out->currentMode()) {
        return;
    }
    const auto mode = bestMode(out, out->currentMode()->size(), refresh);
    if (mode) {
        out->setCurrentModeId(mode->id());
        apply();
    }
}

void Displays::setScale(int row, double scale)
{
    auto out = output(row);
    if (!out) {
        return;
    }
    out->setScale(scale);
    apply();
}

void Displays::setRotation(int row, int degrees)
{
    auto out = output(row);
    if (!out) {
        return;
    }
    KScreen::Output::Rotation rotation = KScreen::Output::None;
    switch (degrees) {
    case 90:
        rotation = KScreen::Output::Left;
        break;
    case 180:
        rotation = KScreen::Output::Inverted;
        break;
    case 270:
        rotation = KScreen::Output::Right;
        break;
    }
    out->setRotation(rotation);
    apply();
}

void Displays::setEnabled(int row, bool enabled)
{
    auto out = output(row);
    if (!out) {
        return;
    }
    if (!enabled) {
        int on = 0;
        for (int id : std::as_const(m_ids)) {
            on += m_config->output(id)->isEnabled() ? 1 : 0;
        }
        if (on <= 1) {
            return;
        }
    }
    out->setEnabled(enabled);
    apply();
}

void Displays::setPrimary(int row)
{
    auto out = output(row);
    if (!out) {
        return;
    }
    m_config->setPrimaryOutput(out);
    apply();
}
