// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: GPL-2.0-or-later

#include "appicons.h"
#include "appiconsync.h"

#include <QFile>
#include <QGuiApplication>
#include <QImageReader>
#include <QPainter>
#include <QPolygonF>
#include <QTemporaryDir>
#include <QTextStream>

#include <cmath>

namespace
{
const AppIcons::Palette TestPalette{QColor(0xff, 0xdb, 0xcc), QColor(0x37, 0x0e, 0x00)};

QImage blank()
{
    QImage image(AppIcons::Size, AppIcons::Size, QImage::Format_ARGB32_Premultiplied);
    image.fill(Qt::transparent);
    return image;
}

QImage disc()
{
    QImage image = blank();
    QPainter painter(&image);
    painter.setRenderHint(QPainter::Antialiasing);
    painter.setPen(Qt::NoPen);
    painter.setBrush(QColor(0xd0, 0x20, 0x20));
    painter.drawEllipse(QRectF(28, 28, 200, 200));
    return image.convertToFormat(QImage::Format_ARGB32);
}

QImage tile()
{
    QImage image = blank();
    QPainter painter(&image);
    painter.setRenderHint(QPainter::Antialiasing);
    painter.setPen(Qt::NoPen);
    painter.setBrush(QColor(0x20, 0x50, 0xd0));
    painter.drawRoundedRect(QRectF(18, 18, 220, 220), 40, 40);
    painter.setPen(QPen(Qt::white, 26, Qt::SolidLine, Qt::RoundCap));
    painter.drawLine(QPointF(78, 78), QPointF(178, 178));
    painter.drawLine(QPointF(178, 78), QPointF(78, 178));
    return image.convertToFormat(QImage::Format_ARGB32);
}

QImage arrow()
{
    QImage image = blank();
    QPainter painter(&image);
    painter.setRenderHint(QPainter::Antialiasing);
    painter.setPen(Qt::NoPen);
    painter.setBrush(QColor(0x30, 0x90, 0x40));
    painter.drawPolygon(QPolygonF({QPointF(128, 20), QPointF(236, 220), QPointF(128, 170), QPointF(20, 220)}));
    return image.convertToFormat(QImage::Format_ARGB32);
}

bool near(QRgb pixel, const QColor &colour, int tolerance)
{
    return std::abs(qRed(pixel) - colour.red()) <= tolerance && std::abs(qGreen(pixel) - colour.green()) <= tolerance
        && std::abs(qBlue(pixel) - colour.blue()) <= tolerance && qAlpha(pixel) > 240;
}

int count(const QImage &image, const QColor &colour)
{
    int found = 0;
    for (int y = 0; y < image.height(); ++y) {
        for (int x = 0; x < image.width(); ++x) {
            found += near(image.pixel(x, y), colour, 24);
        }
    }
    return found;
}

int selfTest()
{
    QTextStream err(stderr);
    int failures = 0;
    const auto check = [&](bool ok, const char *what) {
        if (!ok) {
            err << "kernora-app-icons self-test: " << what << Qt::endl;
            ++failures;
        }
    };
    const int c = AppIcons::Size / 2;
    const int edge = c + qRound(AppIcons::Size * 22.0 / 48.0 * 0.95);
    const int outside = c + qRound(AppIcons::Size * 22.0 / 48.0) + 4;

    check(AppIcons::shape(disc()) == AppIcons::Shape::Circle, "a disc is not seen as round");
    check(AppIcons::shape(tile()) == AppIcons::Shape::Square, "a rounded tile is not seen as a square");
    check(AppIcons::shape(arrow()) == AppIcons::Shape::Free, "an arrow is not seen as a free shape");

    const QImage round = AppIcons::standard(disc());
    check(near(round.pixel(edge, c), QColor(0xd0, 0x20, 0x20), 24), "a round icon does not fill the circle");
    check(qAlpha(round.pixel(outside, c)) == 0 && qAlpha(round.pixel(2, 2)) == 0, "a round icon spills out of the circle");
    check(count(round, Qt::white) == 0, "a round icon got a backing");

    const QImage backed = AppIcons::standard(arrow());
    check(near(backed.pixel(edge, c), Qt::white, 4), "a free icon has no white backing");
    check(qAlpha(backed.pixel(outside, c)) == 0, "the backing is bigger than the circle");
    check(count(backed, QColor(0x30, 0x90, 0x40)) > 2000, "the free icon is missing on its backing");

    const QImage glyph = AppIcons::themed(tile(), TestPalette);
    check(near(glyph.pixel(edge, c), TestPalette.container, 4), "a themed icon has no container circle");
    check(count(glyph, TestPalette.ink) > 1500, "a themed tile lost its glyph");
    check(count(glyph, QColor(0x20, 0x50, 0xd0)) == 0, "a themed icon kept its own colours");

    const QImage silhouette = AppIcons::themed(arrow(), TestPalette);
    check(near(silhouette.pixel(edge, c), TestPalette.container, 4), "a themed free icon has no container circle");
    check(count(silhouette, TestPalette.ink) > 1500, "a themed free icon lost its glyph");

    const QByteArray svg = AppIcons::svg(backed);
    check(svg.contains("viewBox=\"0 0 48 48\"") && svg.contains("data:image/png;base64,"), "the svg wrapper is wrong");

    if (QImageReader::supportedImageFormats().contains("svg")) {
        QTemporaryDir dir;
        QFile file(dir.filePath(QStringLiteral("disc.svg")));
        file.open(QIODevice::WriteOnly);
        file.write("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"48\" height=\"48\"><circle cx=\"24\" cy=\"24\" r=\"20\" fill=\"#d02020\"/></svg>");
        file.close();
        const QImage loaded = AppIcons::load(file.fileName());
        check(loaded.size() == QSize(AppIcons::Size, AppIcons::Size) && AppIcons::shape(loaded) == AppIcons::Shape::Circle,
              "an svg icon does not load at full size");
    }

    if (failures == 0) {
        QTextStream(stdout) << "kernora-app-icons self-test: OK" << Qt::endl;
    }
    return failures == 0 ? 0 : 1;
}
}

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    const QStringList args = app.arguments().mid(1);
    if (args.value(0) == QLatin1String("--self-test")) {
        return selfTest();
    }
    if (args.value(0) == QLatin1String("sync")) {
        AppIconSync::syncNow();
        return 0;
    }
    if (args.value(0) == QLatin1String("render") && args.size() >= 3) {
        const QImage icon = AppIcons::load(args.at(1));
        if (icon.isNull()) {
            return 1;
        }
        const QImage result = args.contains(QLatin1String("--themed")) ? AppIcons::themed(icon, TestPalette) : AppIcons::standard(icon);
        return result.save(args.at(2)) ? 0 : 1;
    }
    QTextStream(stderr) << "usage: kernora-app-icons sync | render <icon> <out.png> [--themed] | --self-test" << Qt::endl;
    return 2;
}
