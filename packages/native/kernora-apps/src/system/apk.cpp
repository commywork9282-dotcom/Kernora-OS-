// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "apk.h"

#include <KCompressionDevice>

#include <QBuffer>
#include <QColor>
#include <QFile>
#include <QHash>
#include <QPainter>
#include <QPainterPath>
#include <QSvgRenderer>
#include <QtEndian>

#include <bit>
#include <optional>

namespace Apk
{
namespace
{

enum : quint16 {
    StringPoolChunk = 0x0001,
    TableChunk = 0x0002,
    XmlChunk = 0x0003,
    XmlStartElement = 0x0102,
    XmlEndElement = 0x0103,
    XmlResourceMap = 0x0180,
    PackageChunk = 0x0200,
    TypeChunk = 0x0201,
};

enum : quint8 {
    TypeNull = 0x00,
    TypeReference = 0x01,
    TypeString = 0x03,
    TypeFloat = 0x04,
    TypeDimension = 0x05,
    TypeFraction = 0x06,
    TypeIntDec = 0x10,
    TypeIntHex = 0x11,
    TypeBoolean = 0x12,
    TypeColorArgb8 = 0x1c,
    TypeColorRgb8 = 0x1d,
    TypeColorArgb4 = 0x1e,
    TypeColorRgb4 = 0x1f,
};

constexpr quint32 AttrLabel = 0x01010001;
constexpr quint32 AttrIcon = 0x01010002;
constexpr quint32 AttrVersionCode = 0x0101021b;
constexpr quint32 AttrVersionName = 0x0101021c;
constexpr quint32 AttrMinSdk = 0x0101020c;
constexpr quint32 AttrTargetSdk = 0x01010270;
constexpr qint64 LargestEntry = 64 * 1024 * 1024;
constexpr int DeepestReference = 8;

class Bytes
{
public:
    explicit Bytes(const QByteArray &data)
        : m_data(data)
    {
    }

    bool fits(qsizetype offset, qsizetype length) const
    {
        return offset >= 0 && length >= 0 && offset <= m_data.size() - length;
    }
    quint8 u8(qsizetype offset) const
    {
        return fits(offset, 1) ? quint8(m_data[offset]) : 0;
    }
    quint16 u16(qsizetype offset) const
    {
        return fits(offset, 2) ? qFromLittleEndian<quint16>(m_data.constData() + offset) : 0;
    }
    quint32 u32(qsizetype offset) const
    {
        return fits(offset, 4) ? qFromLittleEndian<quint32>(m_data.constData() + offset) : 0;
    }
    const char *at(qsizetype offset) const
    {
        return m_data.constData() + offset;
    }

private:
    const QByteArray &m_data;
};

class Archive
{
public:
    explicit Archive(const QString &path)
        : m_file(path)
    {
        if (!m_file.open(QIODevice::ReadOnly)) {
            return;
        }
        const qint64 size = m_file.size();
        const qint64 tail = qMin<qint64>(size, 65557);
        m_file.seek(size - tail);
        const QByteArray end = m_file.read(tail);
        const Bytes last(end);
        qsizetype record = -1;
        for (qsizetype at = end.size() - 22; at >= 0; --at) {
            if (last.u32(at) == 0x06054b50) {
                record = at;
                break;
            }
        }
        if (record < 0) {
            return;
        }
        const quint16 count = last.u16(record + 10);
        const quint32 directorySize = last.u32(record + 12);
        const quint32 directoryOffset = last.u32(record + 16);
        if (qint64(directoryOffset) + directorySize > size || directorySize > LargestEntry) {
            return;
        }
        m_file.seek(directoryOffset);
        const QByteArray directory = m_file.read(directorySize);
        const Bytes bytes(directory);
        qsizetype at = 0;
        for (quint16 i = 0; i < count && bytes.u32(at) == 0x02014b50; ++i) {
            const quint16 nameLength = bytes.u16(at + 28);
            if (!bytes.fits(at + 46, nameLength)) {
                break;
            }
            const QString name = QString::fromUtf8(bytes.at(at + 46), nameLength);
            m_entries.insert(name, {bytes.u16(at + 10), bytes.u32(at + 20), bytes.u32(at + 24), bytes.u32(at + 42)});
            at += 46 + nameLength + bytes.u16(at + 30) + bytes.u16(at + 32);
        }
    }

    bool isValid() const
    {
        return !m_entries.isEmpty();
    }

    QByteArray file(const QString &name) const
    {
        const auto found = m_entries.constFind(name);
        if (found == m_entries.cend() || found->size > LargestEntry || found->packed > LargestEntry) {
            return {};
        }
        if (!m_file.seek(found->offset)) {
            return {};
        }
        const QByteArray header = m_file.read(30);
        const Bytes local(header);
        if (local.u32(0) != 0x04034b50 || !m_file.seek(found->offset + 30 + local.u16(26) + local.u16(28))) {
            return {};
        }
        QByteArray packed = m_file.read(found->packed);
        if (found->method == 0) {
            return packed;
        }
        if (found->method != 8) {
            return {};
        }
        QBuffer buffer(&packed);
        KCompressionDevice inflater(&buffer, false, KCompressionDevice::GZip);
        inflater.setSkipHeaders();
        if (!inflater.open(QIODevice::ReadOnly)) {
            return {};
        }
        const QByteArray data = inflater.read(found->size);
        return data.size() == qsizetype(found->size) ? data : QByteArray();
    }

    QStringList folders(const QString &parent) const
    {
        QStringList found;
        for (auto it = m_entries.cbegin(); it != m_entries.cend(); ++it) {
            if (!it.key().startsWith(parent)) {
                continue;
            }
            const QString folder = it.key().mid(parent.size()).section(QLatin1Char('/'), 0, 0);
            if (!folder.isEmpty() && it.key().size() > parent.size() + folder.size() + 1 && !found.contains(folder)) {
                found.append(folder);
            }
        }
        found.sort();
        return found;
    }

private:
    struct Entry {
        quint16 method = 0;
        quint32 packed = 0;
        quint32 size = 0;
        quint32 offset = 0;
    };

    mutable QFile m_file;
    QHash<QString, Entry> m_entries;
};

QStringList readStringPool(const Bytes &bytes, qsizetype offset)
{
    QStringList strings;
    const quint16 headerSize = bytes.u16(offset + 2);
    const quint32 chunkSize = bytes.u32(offset + 4);
    const quint32 count = bytes.u32(offset + 8);
    const bool utf8 = bytes.u32(offset + 16) & 0x100;
    const qsizetype base = offset + bytes.u32(offset + 20);
    if (!bytes.fits(offset, chunkSize) || count > chunkSize / 4) {
        return strings;
    }
    strings.reserve(count);
    for (quint32 i = 0; i < count; ++i) {
        qsizetype at = base + bytes.u32(offset + headerSize + qsizetype(i) * 4);
        if (utf8) {
            if (bytes.u8(at++) & 0x80) {
                ++at;
            }
            quint32 length = bytes.u8(at++);
            if (length & 0x80) {
                length = ((length & 0x7f) << 8) | bytes.u8(at++);
            }
            strings.append(bytes.fits(at, length) ? QString::fromUtf8(bytes.at(at), length) : QString());
        } else {
            quint32 length = bytes.u16(at);
            at += 2;
            if (length & 0x8000) {
                length = ((length & 0x7fff) << 16) | bytes.u16(at);
                at += 2;
            }
            QString text;
            if (bytes.fits(at, qsizetype(length) * 2)) {
                text.resize(length);
                for (quint32 c = 0; c < length; ++c) {
                    text[c] = QChar(bytes.u16(at + qsizetype(c) * 2));
                }
            }
            strings.append(text);
        }
    }
    return strings;
}

struct Value {
    quint8 type = TypeNull;
    quint32 data = 0;
};

struct Attribute {
    QString name;
    quint32 id = 0;
    Value value;
    QString text;
};

struct Element {
    QString name;
    int depth = 0;
    QList<Attribute> attributes;

    const Attribute *find(const QString &wanted, quint32 id = 0) const
    {
        for (const Attribute &attribute : attributes) {
            if (attribute.name == wanted || (id != 0 && attribute.id == id)) {
                return &attribute;
            }
        }
        return nullptr;
    }
};

QList<Element> readXml(const QByteArray &data)
{
    const Bytes bytes(data);
    QList<Element> elements;
    if (bytes.u16(0) != XmlChunk) {
        return elements;
    }
    QStringList pool;
    QList<quint32> ids;
    int depth = 0;
    qsizetype offset = bytes.u16(2);
    while (bytes.fits(offset, 8)) {
        const quint16 type = bytes.u16(offset);
        const quint16 headerSize = bytes.u16(offset + 2);
        const quint32 size = bytes.u32(offset + 4);
        if (size < 8 || !bytes.fits(offset, size)) {
            break;
        }
        if (type == StringPoolChunk) {
            pool = readStringPool(bytes, offset);
        } else if (type == XmlResourceMap) {
            for (qsizetype at = offset + headerSize; at + 4 <= offset + size; at += 4) {
                ids.append(bytes.u32(at));
            }
        } else if (type == XmlStartElement) {
            const qsizetype extension = offset + headerSize;
            Element element;
            element.depth = depth++;
            element.name = pool.value(bytes.u32(extension + 4));
            const quint16 start = bytes.u16(extension + 8);
            const quint16 stride = bytes.u16(extension + 10);
            const quint16 count = bytes.u16(extension + 12);
            for (quint16 i = 0; i < count; ++i) {
                const qsizetype at = extension + start + qsizetype(i) * stride;
                Attribute attribute;
                const quint32 name = bytes.u32(at + 4);
                attribute.name = pool.value(name);
                attribute.id = name < quint32(ids.size()) ? ids[name] : 0;
                attribute.value = {bytes.u8(at + 15), bytes.u32(at + 16)};
                const quint32 raw = bytes.u32(at + 8);
                attribute.text = raw != 0xffffffff ? pool.value(raw)
                    : (attribute.value.type == TypeString ? pool.value(attribute.value.data) : QString());
                element.attributes.append(attribute);
            }
            elements.append(element);
        } else if (type == XmlEndElement) {
            depth = qMax(0, depth - 1);
        }
        offset += size;
    }
    return elements;
}

float complexToFloat(quint32 data)
{
    static const float multipliers[] = {1.0f / 256, 1.0f / (1 << 7) / 256, 1.0f / (1 << 15) / 256, 1.0f / (1 << 23) / 256};
    return float(qint32(data & 0xffffff00)) * multipliers[(data >> 4) & 3];
}

std::optional<QColor> colorOf(const Value &value)
{
    const quint32 d = value.data;
    switch (value.type) {
    case TypeColorArgb8:
        return QColor::fromRgba(d);
    case TypeColorRgb8:
        return QColor::fromRgb(d | 0xff000000);
    case TypeColorArgb4:
        return QColor(((d >> 8) & 0xf) * 17, ((d >> 4) & 0xf) * 17, (d & 0xf) * 17, ((d >> 12) & 0xf) * 17);
    case TypeColorRgb4:
        return QColor(((d >> 8) & 0xf) * 17, ((d >> 4) & 0xf) * 17, (d & 0xf) * 17);
    default:
        return std::nullopt;
    }
}

std::optional<QColor> frameworkColor(quint32 id)
{
    switch (id) {
    case 0x01060000:
    case 0x0106000c:
        return QColor(Qt::black);
    case 0x01060001:
    case 0x0106000b:
        return QColor(Qt::white);
    case 0x01060002:
        return QColor(0xaa, 0xaa, 0xaa);
    case 0x0106000d:
        return QColor(Qt::transparent);
    default:
        return std::nullopt;
    }
}

struct Config {
    QByteArray language;
    quint16 density = 0;
};

struct Entry {
    Config config;
    Value value;
};

class Table
{
public:
    void read(const QByteArray &data)
    {
        const Bytes bytes(data);
        if (bytes.u16(0) != TableChunk) {
            return;
        }
        qsizetype offset = bytes.u16(2);
        while (bytes.fits(offset, 8)) {
            const quint16 type = bytes.u16(offset);
            const quint16 headerSize = bytes.u16(offset + 2);
            const quint32 size = bytes.u32(offset + 4);
            if (size < 8 || !bytes.fits(offset, size)) {
                break;
            }
            if (type == StringPoolChunk) {
                m_strings = readStringPool(bytes, offset);
            } else if (type == PackageChunk) {
                readPackage(bytes, offset, headerSize, size);
            }
            offset += size;
        }
    }

    QList<Entry> entries(quint32 id) const
    {
        return m_entries.value(id);
    }

    QString string(quint32 index) const
    {
        return m_strings.value(index);
    }

private:
    void readPackage(const Bytes &bytes, qsizetype offset, quint16 headerSize, quint32 size)
    {
        const quint32 packageId = bytes.u32(offset + 8);
        const qsizetype end = offset + size;
        qsizetype at = offset + headerSize;
        while (at + 8 <= end) {
            const quint16 type = bytes.u16(at);
            const quint16 header = bytes.u16(at + 2);
            const quint32 chunk = bytes.u32(at + 4);
            if (chunk < 8 || at + chunk > end) {
                break;
            }
            if (type == TypeChunk) {
                readType(bytes, at, header, packageId);
            }
            at += chunk;
        }
    }

    void readType(const Bytes &bytes, qsizetype offset, quint16 headerSize, quint32 packageId)
    {
        const quint8 typeId = bytes.u8(offset + 8);
        const quint8 flags = bytes.u8(offset + 9);
        const quint32 count = bytes.u32(offset + 12);
        const qsizetype base = offset + bytes.u32(offset + 16);
        const qsizetype config = offset + 20;
        Config parsed;
        const quint32 configSize = bytes.u32(config);
        if (configSize >= 12 && bytes.u8(config + 8) != 0 && !(bytes.u8(config + 8) & 0x80)) {
            parsed.language = QByteArray(bytes.at(config + 8), 2);
        }
        if (configSize >= 16) {
            parsed.density = bytes.u16(config + 14);
        }
        const qsizetype table = offset + headerSize;
        const bool sparse = flags & 0x01;
        const bool narrow = flags & 0x02;
        for (quint32 i = 0; i < count; ++i) {
            quint32 index = i;
            qsizetype entryOffset = 0;
            if (sparse) {
                index = bytes.u16(table + qsizetype(i) * 4);
                entryOffset = qsizetype(bytes.u16(table + qsizetype(i) * 4 + 2)) * 4;
            } else if (narrow) {
                const quint16 stored = bytes.u16(table + qsizetype(i) * 2);
                if (stored == 0xffff) {
                    continue;
                }
                entryOffset = qsizetype(stored) * 4;
            } else {
                const quint32 stored = bytes.u32(table + qsizetype(i) * 4);
                if (stored == 0xffffffff) {
                    continue;
                }
                entryOffset = stored;
            }
            const qsizetype entry = base + entryOffset;
            if (!bytes.fits(entry, 8)) {
                continue;
            }
            const quint16 entrySize = bytes.u16(entry);
            const quint16 entryFlags = bytes.u16(entry + 2);
            Value value;
            if (entryFlags & 0x0008) {
                value = {quint8(entryFlags >> 8), bytes.u32(entry + 4)};
            } else if (entryFlags & 0x0001) {
                continue;
            } else {
                value = {bytes.u8(entry + entrySize + 3), bytes.u32(entry + entrySize + 4)};
            }
            const quint32 id = (packageId << 24) | (quint32(typeId) << 16) | (index & 0xffff);
            m_entries[id].append({parsed, value});
        }
    }

    QStringList m_strings;
    QHash<quint32, QList<Entry>> m_entries;
};

int densityRank(quint16 density)
{
    if (density == 0 || density == 0xffff) {
        return 160;
    }
    return density == 0xfffe ? 0 : density;
}

bool isBitmap(const QString &path)
{
    return path.endsWith(QLatin1String(".png")) || path.endsWith(QLatin1String(".webp"))
        || path.endsWith(QLatin1String(".jpg")) || path.endsWith(QLatin1String(".jpeg"));
}

class Resources
{
public:
    Resources(const Archive &archive, const QByteArray &language)
        : m_archive(archive)
        , m_language(language)
    {
        m_table.read(file(QStringLiteral("resources.arsc")));
    }

    QByteArray file(const QString &path) const
    {
        return m_archive.file(path);
    }

    QString text(const Attribute *attribute) const
    {
        if (!attribute) {
            return {};
        }
        if (attribute->value.type != TypeReference) {
            return attribute->text;
        }
        return text(attribute->value.data, 0);
    }

    std::optional<Value> number(const Attribute *attribute) const
    {
        if (!attribute) {
            return std::nullopt;
        }
        Value value = attribute->value;
        for (int depth = 0; value.type == TypeReference && depth < DeepestReference; ++depth) {
            const QList<Entry> found = m_table.entries(value.data);
            if (found.isEmpty()) {
                return std::nullopt;
            }
            value = found.first().value;
        }
        return value.type == TypeReference ? std::nullopt : std::optional<Value>(value);
    }

    Value pick(quint32 id, bool preferXml) const
    {
        Value best;
        int bestRank = -1;
        for (int depth = 0; depth < DeepestReference; ++depth) {
            const QList<Entry> found = m_table.entries(id);
            best = Value{};
            if (found.isEmpty()) {
                return best;
            }
            bestRank = -1;
            for (const Entry &entry : found) {
                int rank = densityRank(entry.config.density);
                if (entry.value.type == TypeString) {
                    const QString path = m_table.string(entry.value.data);
                    if (path.endsWith(QLatin1String(".xml"))) {
                        rank = preferXml ? 100000 : -1;
                    } else if (!isBitmap(path)) {
                        rank = -1;
                    }
                }
                if (rank > bestRank) {
                    bestRank = rank;
                    best = entry.value;
                }
            }
            if (best.type != TypeReference) {
                return best;
            }
            id = best.data;
        }
        return best;
    }

    QString path(const Value &value) const
    {
        return value.type == TypeString ? m_table.string(value.data) : QString();
    }

private:
    QString text(quint32 id, int depth) const
    {
        if (depth >= DeepestReference) {
            return {};
        }
        const QList<Entry> found = m_table.entries(id);
        const Entry *chosen = nullptr;
        for (const Entry &entry : found) {
            if (!m_language.isEmpty() && entry.config.language == m_language) {
                chosen = &entry;
                break;
            }
            if (entry.config.language.isEmpty() && !chosen) {
                chosen = &entry;
            }
        }
        if (!chosen && !found.isEmpty()) {
            chosen = &found.first();
        }
        if (!chosen) {
            return {};
        }
        if (chosen->value.type == TypeReference) {
            return text(chosen->value.data, depth + 1);
        }
        return chosen->value.type == TypeString ? m_table.string(chosen->value.data) : QString();
    }

    const Archive &m_archive;
    QByteArray m_language;
    Table m_table;
};

class Painter
{
public:
    explicit Painter(const Resources &resources)
        : m_resources(resources)
    {
    }

    bool paint(QPainter &painter, const QRectF &rect, const Attribute *attribute, int depth = 0) const
    {
        if (!attribute || depth >= DeepestReference) {
            return false;
        }
        Value value = attribute->value;
        if (value.type == TypeString) {
            return paintFile(painter, rect, attribute->text, depth);
        }
        return paintValue(painter, rect, value, depth);
    }

    bool paintValue(QPainter &painter, const QRectF &rect, Value value, int depth) const
    {
        if (value.type == TypeReference) {
            if (const std::optional<QColor> color = frameworkColor(value.data)) {
                painter.fillRect(rect, *color);
                return true;
            }
            value = m_resources.pick(value.data, true);
        }
        if (const std::optional<QColor> color = colorOf(value)) {
            painter.fillRect(rect, *color);
            return true;
        }
        return value.type == TypeString && paintFile(painter, rect, m_resources.path(value), depth);
    }

private:
    bool paintFile(QPainter &painter, const QRectF &rect, const QString &path, int depth) const
    {
        if (isBitmap(path)) {
            const QImage image = QImage::fromData(m_resources.file(path));
            if (image.isNull()) {
                return false;
            }
            painter.drawImage(rect, image);
            return true;
        }
        if (!path.endsWith(QLatin1String(".xml"))) {
            return false;
        }
        const QList<Element> elements = readXml(m_resources.file(path));
        if (elements.isEmpty()) {
            return false;
        }
        const Element &root = elements.first();
        if (root.name == QLatin1String("vector")) {
            QSvgRenderer renderer(vectorToSvg(elements));
            if (!renderer.isValid()) {
                return false;
            }
            renderer.render(&painter, rect);
            return true;
        }
        if (root.name == QLatin1String("bitmap")) {
            return paint(painter, rect, root.find(QStringLiteral("src")), depth + 1);
        }
        if (root.name == QLatin1String("inset")) {
            return paint(painter, insetRect(root, rect), root.find(QStringLiteral("drawable")), depth + 1);
        }
        if (root.name == QLatin1String("color")) {
            return paint(painter, rect, root.find(QStringLiteral("color")), depth + 1);
        }
        if (root.name == QLatin1String("shape")) {
            for (const Element &element : elements) {
                if (element.name != QLatin1String("solid")) {
                    continue;
                }
                const std::optional<QColor> color = colorOf(resolved(element.find(QStringLiteral("color"))));
                if (!color) {
                    return false;
                }
                const Attribute *shape = root.find(QStringLiteral("shape"));
                painter.save();
                painter.setPen(Qt::NoPen);
                painter.setBrush(*color);
                if (shape && shape->value.data == 1) {
                    painter.drawEllipse(rect);
                } else {
                    painter.drawRect(rect);
                }
                painter.restore();
                return true;
            }
            return false;
        }
        if (root.name == QLatin1String("layer-list")) {
            bool painted = false;
            for (const Element &element : elements) {
                if (element.depth != 1 || element.name != QLatin1String("item")) {
                    continue;
                }
                painted |= paint(painter, insetRect(element, rect), element.find(QStringLiteral("drawable")), depth + 1);
            }
            return painted;
        }
        return false;
    }

    Value resolved(const Attribute *attribute) const
    {
        const std::optional<Value> value = m_resources.number(attribute);
        return value ? *value : Value{};
    }

    double amount(const Attribute *attribute, double whole, double fallback) const
    {
        const Value value = resolved(attribute);
        switch (value.type) {
        case TypeFraction:
            return complexToFloat(value.data) * whole;
        case TypeDimension:
            return complexToFloat(value.data) * whole / 108.0;
        case TypeFloat:
            return std::bit_cast<float>(value.data) * whole;
        default:
            return fallback;
        }
    }

    QRectF insetRect(const Element &element, const QRectF &rect) const
    {
        const double all = amount(element.find(QStringLiteral("inset")), rect.width(), 0);
        const double left = amount(element.find(QStringLiteral("insetLeft")), rect.width(), amount(element.find(QStringLiteral("left")), rect.width(), all));
        const double top = amount(element.find(QStringLiteral("insetTop")), rect.height(), amount(element.find(QStringLiteral("top")), rect.height(), all));
        const double right = amount(element.find(QStringLiteral("insetRight")), rect.width(), amount(element.find(QStringLiteral("right")), rect.width(), all));
        const double bottom = amount(element.find(QStringLiteral("insetBottom")), rect.height(), amount(element.find(QStringLiteral("bottom")), rect.height(), all));
        return rect.adjusted(left, top, -right, -bottom);
    }

    double real(const Element &element, const QString &name, double fallback) const
    {
        const Value value = resolved(element.find(name));
        switch (value.type) {
        case TypeFloat:
            return std::bit_cast<float>(value.data);
        case TypeDimension:
            return complexToFloat(value.data);
        case TypeIntDec:
        case TypeIntHex:
            return qint32(value.data);
        default:
            return fallback;
        }
    }

    static QString number(double value)
    {
        return QString::number(value, 'g', 8);
    }

    QString paintFor(const Attribute *attribute, double alpha, QString &defs, int &serial, QString &opacity) const
    {
        opacity.clear();
        if (!attribute) {
            return QStringLiteral("none");
        }
        Value value = attribute->value;
        if (value.type == TypeReference) {
            if (const std::optional<QColor> color = frameworkColor(value.data)) {
                opacity = number(color->alphaF() * alpha);
                return color->name(QColor::HexRgb);
            }
            value = m_resources.pick(value.data, true);
        }
        if (const std::optional<QColor> color = colorOf(value)) {
            opacity = number(color->alphaF() * alpha);
            return color->name(QColor::HexRgb);
        }
        const QString path = value.type == TypeString ? m_resources.path(value) : attribute->text;
        if (!path.endsWith(QLatin1String(".xml"))) {
            return QStringLiteral("none");
        }
        const QList<Element> elements = readXml(m_resources.file(path));
        if (elements.isEmpty()) {
            return QStringLiteral("none");
        }
        const Element &root = elements.first();
        if (root.name == QLatin1String("selector")) {
            for (qsizetype i = elements.size() - 1; i > 0; --i) {
                if (elements[i].name == QLatin1String("item")) {
                    return paintFor(elements[i].find(QStringLiteral("color")), alpha, defs, serial, opacity);
                }
            }
            return QStringLiteral("none");
        }
        if (root.name != QLatin1String("gradient")) {
            return QStringLiteral("none");
        }
        QList<std::pair<double, QColor>> stops;
        for (const Element &element : elements) {
            if (element.name == QLatin1String("item")) {
                const std::optional<QColor> color = colorOf(resolved(element.find(QStringLiteral("color"))));
                if (color) {
                    stops.append({real(element, QStringLiteral("offset"), 0), *color});
                }
            }
        }
        if (stops.isEmpty()) {
            const std::optional<QColor> start = colorOf(resolved(root.find(QStringLiteral("startColor"))));
            const std::optional<QColor> center = colorOf(resolved(root.find(QStringLiteral("centerColor"))));
            const std::optional<QColor> end = colorOf(resolved(root.find(QStringLiteral("endColor"))));
            if (start) {
                stops.append({0, *start});
            }
            if (center) {
                stops.append({0.5, *center});
            }
            if (end) {
                stops.append({1, *end});
            }
        }
        if (stops.isEmpty()) {
            return QStringLiteral("none");
        }
        const QString id = QStringLiteral("g%1").arg(++serial);
        const int kind = int(resolved(root.find(QStringLiteral("type"))).data);
        QString gradient;
        if (kind == 1) {
            gradient = QStringLiteral("<radialGradient id=\"%1\" gradientUnits=\"userSpaceOnUse\" cx=\"%2\" cy=\"%3\" r=\"%4\">")
                           .arg(id, number(real(root, QStringLiteral("centerX"), 0)), number(real(root, QStringLiteral("centerY"), 0)),
                                number(real(root, QStringLiteral("gradientRadius"), 1)));
        } else {
            gradient = QStringLiteral("<linearGradient id=\"%1\" gradientUnits=\"userSpaceOnUse\" x1=\"%2\" y1=\"%3\" x2=\"%4\" y2=\"%5\">")
                           .arg(id, number(real(root, QStringLiteral("startX"), 0)), number(real(root, QStringLiteral("startY"), 0)),
                                number(real(root, QStringLiteral("endX"), 0)), number(real(root, QStringLiteral("endY"), 0)));
        }
        for (const auto &[offset, color] : stops) {
            gradient += QStringLiteral("<stop offset=\"%1\" stop-color=\"%2\" stop-opacity=\"%3\"/>")
                            .arg(number(offset), color.name(QColor::HexRgb), number(color.alphaF()));
        }
        gradient += kind == 1 ? QStringLiteral("</radialGradient>") : QStringLiteral("</linearGradient>");
        defs += gradient;
        opacity = number(alpha);
        return QStringLiteral("url(#%1)").arg(id);
    }

    QByteArray vectorToSvg(const QList<Element> &elements) const
    {
        const Element &root = elements.first();
        const double width = real(root, QStringLiteral("viewportWidth"), 24);
        const double height = real(root, QStringLiteral("viewportHeight"), 24);
        QString defs;
        QString body;
        int serial = 0;
        QList<int> open;
        for (qsizetype i = 1; i < elements.size(); ++i) {
            const Element &element = elements[i];
            while (!open.isEmpty() && element.depth < open.last()) {
                body += QStringLiteral("</g>");
                open.removeLast();
            }
            if (element.name == QLatin1String("group")) {
                const double pivotX = real(element, QStringLiteral("pivotX"), 0);
                const double pivotY = real(element, QStringLiteral("pivotY"), 0);
                body += QStringLiteral("<g transform=\"translate(%1 %2) rotate(%3) scale(%4 %5) translate(%6 %7)\">")
                            .arg(number(real(element, QStringLiteral("translateX"), 0) + pivotX),
                                 number(real(element, QStringLiteral("translateY"), 0) + pivotY),
                                 number(real(element, QStringLiteral("rotation"), 0)),
                                 number(real(element, QStringLiteral("scaleX"), 1)), number(real(element, QStringLiteral("scaleY"), 1)),
                                 number(-pivotX), number(-pivotY));
                open.append(element.depth + 1);
            } else if (element.name == QLatin1String("clip-path")) {
                const QString id = QStringLiteral("c%1").arg(++serial);
                defs += QStringLiteral("<clipPath id=\"%1\"><path d=\"%2\"/></clipPath>")
                            .arg(id, m_resources.text(element.find(QStringLiteral("pathData"))).toHtmlEscaped());
                body += QStringLiteral("<g clip-path=\"url(#%1)\">").arg(id);
                open.append(element.depth);
            } else if (element.name == QLatin1String("path")) {
                QString fillOpacity;
                QString strokeOpacity;
                const QString fill = paintFor(element.find(QStringLiteral("fillColor")), real(element, QStringLiteral("fillAlpha"), 1),
                                              defs, serial, fillOpacity);
                const QString stroke = paintFor(element.find(QStringLiteral("strokeColor")), real(element, QStringLiteral("strokeAlpha"), 1),
                                                defs, serial, strokeOpacity);
                const int fillType = int(real(element, QStringLiteral("fillType"), 0));
                const int cap = int(real(element, QStringLiteral("strokeLineCap"), 0));
                const int join = int(real(element, QStringLiteral("strokeLineJoin"), 0));
                static const char *caps[] = {"butt", "round", "square"};
                static const char *joins[] = {"miter", "round", "bevel"};
                body += QStringLiteral("<path d=\"%1\" fill=\"%2\" fill-rule=\"%3\" stroke=\"%4\" stroke-width=\"%5\" stroke-linecap=\"%6\" stroke-linejoin=\"%7\"")
                            .arg(m_resources.text(element.find(QStringLiteral("pathData"))).toHtmlEscaped(), fill,
                                 fillType == 1 ? QStringLiteral("evenodd") : QStringLiteral("nonzero"), stroke,
                                 number(real(element, QStringLiteral("strokeWidth"), 0)),
                                 QLatin1String(caps[qBound(0, cap, 2)]), QLatin1String(joins[qBound(0, join, 2)]));
                if (!fillOpacity.isEmpty()) {
                    body += QStringLiteral(" fill-opacity=\"%1\"").arg(fillOpacity);
                }
                if (!strokeOpacity.isEmpty()) {
                    body += QStringLiteral(" stroke-opacity=\"%1\"").arg(strokeOpacity);
                }
                body += QStringLiteral("/>");
            }
        }
        while (!open.isEmpty()) {
            body += QStringLiteral("</g>");
            open.removeLast();
        }
        return QStringLiteral("<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 %1 %2\" width=\"%1\" height=\"%2\"><defs>%3</defs><g opacity=\"%4\">%5</g></svg>")
            .arg(number(width), number(height), defs, number(real(root, QStringLiteral("alpha"), 1)), body)
            .toUtf8();
    }

    const Resources &m_resources;
};

QImage renderIcon(const Resources &resources, const Attribute *icon, int size)
{
    if (!icon || icon->value.type != TypeReference) {
        return {};
    }
    const Painter painter(resources);
    const QString adaptive = resources.path(resources.pick(icon->value.data, true));
    if (adaptive.endsWith(QLatin1String(".xml"))) {
        const QList<Element> elements = readXml(resources.file(adaptive));
        if (!elements.isEmpty() && elements.first().name == QLatin1String("adaptive-icon")) {
            QImage image(size, size, QImage::Format_ARGB32_Premultiplied);
            image.fill(Qt::transparent);
            QPainter canvas(&image);
            canvas.setRenderHints(QPainter::Antialiasing | QPainter::SmoothPixmapTransform);
            QPainterPath mask;
            mask.addEllipse(QRectF(0, 0, size, size));
            canvas.setClipPath(mask);
            const QRectF layer(-size * 0.25, -size * 0.25, size * 1.5, size * 1.5);
            bool painted = false;
            for (const Element &element : elements) {
                if (element.depth != 1) {
                    continue;
                }
                if (element.name == QLatin1String("background") && !painter.paint(canvas, layer, element.find(QStringLiteral("drawable")))) {
                    canvas.fillRect(layer, Qt::white);
                } else if (element.name == QLatin1String("foreground")) {
                    painted |= painter.paint(canvas, layer, element.find(QStringLiteral("drawable")));
                }
            }
            canvas.end();
            if (painted) {
                return image;
            }
        }
    }
    const Value bitmap = resources.pick(icon->value.data, false);
    QImage image(size, size, QImage::Format_ARGB32_Premultiplied);
    image.fill(Qt::transparent);
    QPainter canvas(&image);
    canvas.setRenderHints(QPainter::Antialiasing | QPainter::SmoothPixmapTransform);
    const bool painted = painter.paintValue(canvas, QRectF(0, 0, size, size), bitmap, 0);
    canvas.end();
    return painted ? image : QImage();
}

}

Package read(const QString &path, const QString &language, int iconSize)
{
    Package package;
    const Archive archive(path);
    if (!archive.isValid()) {
        package.error = QStringLiteral("unreadable");
        return package;
    }
    const QList<Element> manifest = readXml(archive.file(QStringLiteral("AndroidManifest.xml")));
    if (manifest.isEmpty() || manifest.first().name != QLatin1String("manifest")) {
        package.error = QStringLiteral("not-an-app");
        return package;
    }
    const Resources resources(archive, language.left(2).toLatin1());
    const Element &top = manifest.first();
    if (const Attribute *name = top.find(QStringLiteral("package"))) {
        package.packageName = name->text;
    }
    package.versionName = resources.text(top.find(QStringLiteral("versionName"), AttrVersionName));
    if (const Attribute *code = top.find(QStringLiteral("versionCode"), AttrVersionCode)) {
        package.versionCode = code->value.data;
    }
    for (const Element &element : manifest) {
        if (element.name == QLatin1String("uses-sdk")) {
            const Attribute *minimum = element.find(QStringLiteral("minSdkVersion"), AttrMinSdk);
            const Attribute *target = element.find(QStringLiteral("targetSdkVersion"), AttrTargetSdk);
            if (minimum && minimum->value.type == TypeIntDec) {
                package.minSdk = int(minimum->value.data);
            }
            if (target && target->value.type == TypeIntDec) {
                package.targetSdk = int(target->value.data);
            }
        } else if (element.name == QLatin1String("application")) {
            package.label = resources.text(element.find(QStringLiteral("label"), AttrLabel));
            if (iconSize > 0) {
                package.icon = renderIcon(resources, element.find(QStringLiteral("icon"), AttrIcon), iconSize);
            }
        }
    }
    package.abis = archive.folders(QStringLiteral("lib/"));
    if (package.packageName.isEmpty()) {
        package.error = QStringLiteral("not-an-app");
    }
    return package;
}

}
