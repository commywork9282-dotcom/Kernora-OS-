// SPDX-FileCopyrightText: 2021 Google LLC
// SPDX-FileCopyrightText: 2026 Kernora Developers
// SPDX-License-Identifier: Apache-2.0

#include "wallpapercolours.h"

#include <QImage>
#include <QImageReader>

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <random>
#include <unordered_map>
#include <vector>

namespace Kernora::WallpaperColours
{
namespace
{
constexpr double kPi = 3.14159265358979323846;

struct Lab {
    double l = 0.0;
    double a = 0.0;
    double b = 0.0;

    double deltaE(const Lab &other) const
    {
        const double dl = l - other.l;
        const double da = a - other.a;
        const double db = b - other.b;
        return dl * dl + da * da + db * db;
    }
};

double linearized(int component)
{
    const double normalized = component / 255.0;
    if (normalized <= 0.040449936) {
        return normalized / 12.92 * 100.0;
    }
    return std::pow((normalized + 0.055) / 1.055, 2.4) * 100.0;
}

int delinearized(double component)
{
    const double normalized = component / 100.0;
    double value;
    if (normalized <= 0.0031308) {
        value = normalized * 12.92;
    } else {
        value = 1.055 * std::pow(normalized, 1.0 / 2.4) - 0.055;
    }
    return std::clamp(static_cast<int>(std::round(value * 255.0)), 0, 255);
}

std::array<double, 3> xyzFromArgb(QRgb argb)
{
    const double r = linearized(qRed(argb));
    const double g = linearized(qGreen(argb));
    const double b = linearized(qBlue(argb));
    return {0.41233895 * r + 0.35762064 * g + 0.18051042 * b, 0.21263901 * r + 0.71516868 * g + 0.07219232 * b,
            0.01933082 * r + 0.11919478 * g + 0.95053215 * b};
}

QRgb argbFromXyz(double x, double y, double z)
{
    const double r = 3.2413774792388685 * x - 1.5376652402851851 * y - 0.49885366846268053 * z;
    const double g = -0.9691452513005321 * x + 1.8758853451067872 * y + 0.04156585616912061 * z;
    const double b = 0.05562093689691305 * x - 0.20395524564742123 * y + 1.0571799111220335 * z;
    return qRgb(delinearized(r), delinearized(g), delinearized(b));
}

double labF(double t)
{
    constexpr double e = 216.0 / 24389.0;
    constexpr double kappa = 24389.0 / 27.0;
    return t > e ? std::cbrt(t) : (kappa * t + 16.0) / 116.0;
}

double labInvf(double ft)
{
    constexpr double e = 216.0 / 24389.0;
    constexpr double kappa = 24389.0 / 27.0;
    const double ft3 = ft * ft * ft;
    return ft3 > e ? ft3 : (116.0 * ft - 16.0) / kappa;
}

constexpr std::array<double, 3> kWhite = {95.047, 100.0, 108.883};

Lab labFromArgb(QRgb argb)
{
    const auto xyz = xyzFromArgb(argb);
    const double fx = labF(xyz[0] / kWhite[0]);
    const double fy = labF(xyz[1] / kWhite[1]);
    const double fz = labF(xyz[2] / kWhite[2]);
    return {116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz)};
}

QRgb argbFromLab(const Lab &lab)
{
    const double fy = (lab.l + 16.0) / 116.0;
    const double fx = lab.a / 500.0 + fy;
    const double fz = fy - lab.b / 200.0;
    return argbFromXyz(labInvf(fx) * kWhite[0], labInvf(fy) * kWhite[1], labInvf(fz) * kWhite[2]);
}

double yFromLstar(double lstar)
{
    return 100.0 * labInvf((lstar + 16.0) / 116.0);
}

double sanitizeDegrees(double degrees)
{
    degrees = std::fmod(degrees, 360.0);
    return degrees < 0.0 ? degrees + 360.0 : degrees;
}

int sanitizeDegrees(int degrees)
{
    degrees %= 360;
    return degrees < 0 ? degrees + 360 : degrees;
}

double differenceDegrees(double a, double b)
{
    return 180.0 - std::abs(std::abs(a - b) - 180.0);
}

constexpr double kToCam16[3][3] = {{0.401288, 0.650173, -0.051461}, {-0.250268, 1.204414, 0.045854}, {-0.002079, 0.048952, 0.953127}};

struct Viewing {
    double n;
    double aw;
    double nbb;
    double ncb;
    double c;
    double nc;
    std::array<double, 3> rgbD;
    double fl;
    double flRoot;
    double z;
};

Viewing makeViewing()
{
    const double adapting = (200.0 / kPi) * yFromLstar(50.0) / 100.0;
    std::array<double, 3> white;
    for (int i = 0; i < 3; ++i) {
        white[i] = kToCam16[i][0] * kWhite[0] + kToCam16[i][1] * kWhite[1] + kToCam16[i][2] * kWhite[2];
    }
    const double surround = 2.0;
    const double f = 0.8 + surround / 10.0;
    const double c = f >= 0.9 ? 0.59 + (0.69 - 0.59) * (f - 0.9) * 10.0 : 0.525 + (0.59 - 0.525) * (f - 0.8) * 10.0;
    const double d = std::clamp(f * (1.0 - (1.0 / 3.6) * std::exp((-adapting - 42.0) / 92.0)), 0.0, 1.0);

    Viewing v{};
    v.n = yFromLstar(50.0) / kWhite[1];
    v.nbb = 0.725 / std::pow(v.n, 0.2);
    v.ncb = v.nbb;
    v.c = c;
    v.nc = f;
    for (int i = 0; i < 3; ++i) {
        v.rgbD[i] = d * (100.0 / white[i]) + 1.0 - d;
    }
    const double k = 1.0 / (5.0 * adapting + 1.0);
    const double k4 = k * k * k * k;
    const double k4f = 1.0 - k4;
    v.fl = k4 * adapting + 0.1 * k4f * k4f * std::cbrt(5.0 * adapting);
    v.flRoot = std::pow(v.fl, 0.25);
    v.z = 1.48 + std::sqrt(v.n);
    std::array<double, 3> rgbA;
    for (int i = 0; i < 3; ++i) {
        const double factor = std::pow(v.fl * v.rgbD[i] * white[i] / 100.0, 0.42);
        rgbA[i] = 400.0 * factor / (factor + 27.13);
    }
    v.aw = (40.0 * rgbA[0] + 20.0 * rgbA[1] + rgbA[2]) / 20.0 * v.nbb;
    return v;
}

const Viewing &viewing()
{
    static const Viewing value = makeViewing();
    return value;
}

constexpr int kIndexBits = 5;
constexpr int kIndexCount = (1 << kIndexBits) + 1;
constexpr int kTotalSize = kIndexCount * kIndexCount * kIndexCount;
constexpr int kMaxColors = 256;

int cubeIndex(int r, int g, int b)
{
    return (r << (kIndexBits * 2)) + (r << (kIndexBits + 1)) + (g << kIndexBits) + r + g + b;
}

struct Box {
    int r0 = 0;
    int r1 = 0;
    int g0 = 0;
    int g1 = 0;
    int b0 = 0;
    int b1 = 0;
    int vol = 0;
};

enum class Direction { Red, Green, Blue };

template<typename T>
T volume(const Box &cube, const std::vector<T> &moment)
{
    return moment[cubeIndex(cube.r1, cube.g1, cube.b1)] - moment[cubeIndex(cube.r1, cube.g1, cube.b0)] - moment[cubeIndex(cube.r1, cube.g0, cube.b1)]
        + moment[cubeIndex(cube.r1, cube.g0, cube.b0)] - moment[cubeIndex(cube.r0, cube.g1, cube.b1)] + moment[cubeIndex(cube.r0, cube.g1, cube.b0)]
        + moment[cubeIndex(cube.r0, cube.g0, cube.b1)] - moment[cubeIndex(cube.r0, cube.g0, cube.b0)];
}

int64_t bottom(const Box &cube, Direction direction, const std::vector<int64_t> &moment)
{
    switch (direction) {
    case Direction::Red:
        return -moment[cubeIndex(cube.r0, cube.g1, cube.b1)] + moment[cubeIndex(cube.r0, cube.g1, cube.b0)] + moment[cubeIndex(cube.r0, cube.g0, cube.b1)]
            - moment[cubeIndex(cube.r0, cube.g0, cube.b0)];
    case Direction::Green:
        return -moment[cubeIndex(cube.r1, cube.g0, cube.b1)] + moment[cubeIndex(cube.r1, cube.g0, cube.b0)] + moment[cubeIndex(cube.r0, cube.g0, cube.b1)]
            - moment[cubeIndex(cube.r0, cube.g0, cube.b0)];
    case Direction::Blue:
        return -moment[cubeIndex(cube.r1, cube.g1, cube.b0)] + moment[cubeIndex(cube.r1, cube.g0, cube.b0)] + moment[cubeIndex(cube.r0, cube.g1, cube.b0)]
            - moment[cubeIndex(cube.r0, cube.g0, cube.b0)];
    }
    return 0;
}

int64_t top(const Box &cube, Direction direction, int position, const std::vector<int64_t> &moment)
{
    switch (direction) {
    case Direction::Red:
        return moment[cubeIndex(position, cube.g1, cube.b1)] - moment[cubeIndex(position, cube.g1, cube.b0)] - moment[cubeIndex(position, cube.g0, cube.b1)]
            + moment[cubeIndex(position, cube.g0, cube.b0)];
    case Direction::Green:
        return moment[cubeIndex(cube.r1, position, cube.b1)] - moment[cubeIndex(cube.r1, position, cube.b0)] - moment[cubeIndex(cube.r0, position, cube.b1)]
            + moment[cubeIndex(cube.r0, position, cube.b0)];
    case Direction::Blue:
        return moment[cubeIndex(cube.r1, cube.g1, position)] - moment[cubeIndex(cube.r1, cube.g0, position)] - moment[cubeIndex(cube.r0, cube.g1, position)]
            + moment[cubeIndex(cube.r0, cube.g0, position)];
    }
    return 0;
}

struct Histogram {
    std::vector<int64_t> weights = std::vector<int64_t>(kTotalSize, 0);
    std::vector<int64_t> mr = std::vector<int64_t>(kTotalSize, 0);
    std::vector<int64_t> mg = std::vector<int64_t>(kTotalSize, 0);
    std::vector<int64_t> mb = std::vector<int64_t>(kTotalSize, 0);
    std::vector<double> moments = std::vector<double>(kTotalSize, 0.0);
};

double variance(const Box &cube, const Histogram &h)
{
    const double dr = volume(cube, h.mr);
    const double dg = volume(cube, h.mg);
    const double db = volume(cube, h.mb);
    const double xx = volume(cube, h.moments);
    const double hypotenuse = dr * dr + dg * dg + db * db;
    return xx - hypotenuse / volume(cube, h.weights);
}

double maximize(const Box &cube, Direction direction, int first, int last, int &cut, int64_t wholeW, int64_t wholeR, int64_t wholeG, int64_t wholeB,
                const Histogram &h)
{
    const int64_t bottomR = bottom(cube, direction, h.mr);
    const int64_t bottomG = bottom(cube, direction, h.mg);
    const int64_t bottomB = bottom(cube, direction, h.mb);
    const int64_t bottomW = bottom(cube, direction, h.weights);
    double best = 0.0;
    cut = -1;
    for (int i = first; i < last; ++i) {
        int64_t halfR = bottomR + top(cube, direction, i, h.mr);
        int64_t halfG = bottomG + top(cube, direction, i, h.mg);
        int64_t halfB = bottomB + top(cube, direction, i, h.mb);
        int64_t halfW = bottomW + top(cube, direction, i, h.weights);
        if (halfW == 0) {
            continue;
        }
        double temp = (double(halfR) * halfR + double(halfG) * halfG + double(halfB) * halfB) / double(halfW);
        halfR = wholeR - halfR;
        halfG = wholeG - halfG;
        halfB = wholeB - halfB;
        halfW = wholeW - halfW;
        if (halfW == 0) {
            continue;
        }
        temp += (double(halfR) * halfR + double(halfG) * halfG + double(halfB) * halfB) / double(halfW);
        if (temp > best) {
            best = temp;
            cut = i;
        }
    }
    return best;
}

bool cutBox(Box &one, Box &two, const Histogram &h)
{
    const int64_t wholeR = volume(one, h.mr);
    const int64_t wholeG = volume(one, h.mg);
    const int64_t wholeB = volume(one, h.mb);
    const int64_t wholeW = volume(one, h.weights);
    int cutR;
    int cutG;
    int cutB;
    const double maxR = maximize(one, Direction::Red, one.r0 + 1, one.r1, cutR, wholeW, wholeR, wholeG, wholeB, h);
    const double maxG = maximize(one, Direction::Green, one.g0 + 1, one.g1, cutG, wholeW, wholeR, wholeG, wholeB, h);
    const double maxB = maximize(one, Direction::Blue, one.b0 + 1, one.b1, cutB, wholeW, wholeR, wholeG, wholeB, h);
    Direction direction;
    if (maxR >= maxG && maxR >= maxB) {
        if (cutR < 0) {
            return false;
        }
        direction = Direction::Red;
    } else if (maxG >= maxR && maxG >= maxB) {
        direction = Direction::Green;
    } else {
        direction = Direction::Blue;
    }
    two.r1 = one.r1;
    two.g1 = one.g1;
    two.b1 = one.b1;
    switch (direction) {
    case Direction::Red:
        one.r1 = cutR;
        two.r0 = one.r1;
        two.g0 = one.g0;
        two.b0 = one.b0;
        break;
    case Direction::Green:
        one.g1 = cutG;
        two.r0 = one.r0;
        two.g0 = one.g1;
        two.b0 = one.b0;
        break;
    case Direction::Blue:
        one.b1 = cutB;
        two.r0 = one.r0;
        two.g0 = one.g0;
        two.b0 = one.b1;
        break;
    }
    one.vol = (one.r1 - one.r0) * (one.g1 - one.g0) * (one.b1 - one.b0);
    two.vol = (two.r1 - two.r0) * (two.g1 - two.g0) * (two.b1 - two.b0);
    return true;
}

std::vector<QRgb> quantizeWu(const std::vector<QRgb> &pixels, int maxColors)
{
    if (maxColors <= 0 || maxColors > kMaxColors || pixels.empty()) {
        return {};
    }
    Histogram h;
    constexpr int bitsToRemove = 8 - kIndexBits;
    for (const QRgb pixel : pixels) {
        const int red = qRed(pixel);
        const int green = qGreen(pixel);
        const int blue = qBlue(pixel);
        const int index = cubeIndex((red >> bitsToRemove) + 1, (green >> bitsToRemove) + 1, (blue >> bitsToRemove) + 1);
        h.weights[index] += 1;
        h.mr[index] += red;
        h.mg[index] += green;
        h.mb[index] += blue;
        h.moments[index] += double(red) * red + double(green) * green + double(blue) * blue;
    }
    for (int r = 1; r < kIndexCount; ++r) {
        std::array<int64_t, kIndexCount> area{};
        std::array<int64_t, kIndexCount> areaR{};
        std::array<int64_t, kIndexCount> areaG{};
        std::array<int64_t, kIndexCount> areaB{};
        std::array<double, kIndexCount> area2{};
        for (int g = 1; g < kIndexCount; ++g) {
            int64_t line = 0;
            int64_t lineR = 0;
            int64_t lineG = 0;
            int64_t lineB = 0;
            double line2 = 0.0;
            for (int b = 1; b < kIndexCount; ++b) {
                const int index = cubeIndex(r, g, b);
                line += h.weights[index];
                lineR += h.mr[index];
                lineG += h.mg[index];
                lineB += h.mb[index];
                line2 += h.moments[index];
                area[b] += line;
                areaR[b] += lineR;
                areaG[b] += lineG;
                areaB[b] += lineB;
                area2[b] += line2;
                const int previous = cubeIndex(r - 1, g, b);
                h.weights[index] = h.weights[previous] + area[b];
                h.mr[index] = h.mr[previous] + areaR[b];
                h.mg[index] = h.mg[previous] + areaG[b];
                h.mb[index] = h.mb[previous] + areaB[b];
                h.moments[index] = h.moments[previous] + area2[b];
            }
        }
    }

    std::vector<Box> cubes(kMaxColors);
    cubes[0].r1 = kIndexCount - 1;
    cubes[0].g1 = kIndexCount - 1;
    cubes[0].b1 = kIndexCount - 1;
    std::vector<double> volumeVariance(kMaxColors, 0.0);
    int next = 0;
    for (int i = 1; i < maxColors; ++i) {
        if (cutBox(cubes[next], cubes[i], h)) {
            volumeVariance[next] = cubes[next].vol > 1 ? variance(cubes[next], h) : 0.0;
            volumeVariance[i] = cubes[i].vol > 1 ? variance(cubes[i], h) : 0.0;
        } else {
            volumeVariance[next] = 0.0;
            --i;
        }
        next = 0;
        double temp = volumeVariance[0];
        for (int j = 1; j <= i; ++j) {
            if (volumeVariance[j] > temp) {
                temp = volumeVariance[j];
                next = j;
            }
        }
        if (temp <= 0.0) {
            maxColors = i + 1;
            break;
        }
    }

    std::vector<QRgb> result;
    for (int i = 0; i < maxColors; ++i) {
        const int64_t weight = volume(cubes[i], h.weights);
        if (weight > 0) {
            const int r = int(volume(cubes[i], h.mr) / weight);
            const int g = int(volume(cubes[i], h.mg) / weight);
            const int b = int(volume(cubes[i], h.mb) / weight);
            result.push_back(qRgb(r, g, b));
        }
    }
    return result;
}

std::unordered_map<QRgb, int> quantizeWsmeans(const std::vector<QRgb> &input, const std::vector<QRgb> &starting, int maxColors)
{
    constexpr int kMaxIterations = 10;
    if (maxColors <= 0 || input.empty()) {
        return {};
    }
    maxColors = std::min(maxColors, kMaxColors);

    std::unordered_map<QRgb, int> pixelToCount;
    std::vector<QRgb> pixels;
    std::vector<Lab> points;
    for (const QRgb pixel : input) {
        auto found = pixelToCount.find(pixel);
        if (found != pixelToCount.end()) {
            ++found->second;
        } else {
            pixels.push_back(pixel);
            points.push_back(labFromArgb(pixel));
            pixelToCount.emplace(pixel, 1);
        }
    }
    std::vector<int> counts(pixels.size());
    for (size_t i = 0; i < pixels.size(); ++i) {
        counts[i] = pixelToCount[pixels[i]];
    }

    int clusterCount = std::min<int>(maxColors, int(points.size()));
    if (!starting.empty()) {
        clusterCount = std::min<int>(clusterCount, int(starting.size()));
    }
    std::vector<Lab> clusters;
    for (const QRgb argb : starting) {
        clusters.push_back(labFromArgb(argb));
    }
    clusters.resize(clusterCount);

    std::mt19937 random(0x42688);
    std::vector<int> clusterIndices(points.size());
    for (size_t i = 0; i < points.size(); ++i) {
        clusterIndices[i] = int(random() % uint32_t(clusterCount));
    }

    struct DistanceToIndex {
        double distance = 0.0;
        int index = 0;
    };
    std::vector<std::vector<DistanceToIndex>> distances(clusterCount, std::vector<DistanceToIndex>(clusterCount));
    std::vector<int> pixelCountSums(clusterCount, 0);

    for (int iteration = 0; iteration < kMaxIterations; ++iteration) {
        for (int i = 0; i < clusterCount; ++i) {
            distances[i][i] = {0.0, i};
            for (int j = i + 1; j < clusterCount; ++j) {
                const double distance = clusters[i].deltaE(clusters[j]);
                distances[j][i] = {distance, i};
                distances[i][j] = {distance, j};
            }
        }

        bool moved = false;
        for (size_t i = 0; i < points.size(); ++i) {
            const Lab &point = points[i];
            const int previousIndex = clusterIndices[i];
            const double previousDistance = point.deltaE(clusters[previousIndex]);
            double minimum = previousDistance;
            int newIndex = -1;
            for (int j = 0; j < clusterCount; ++j) {
                if (distances[previousIndex][j].distance >= 4.0 * previousDistance) {
                    continue;
                }
                const double distance = point.deltaE(clusters[j]);
                if (distance < minimum) {
                    minimum = distance;
                    newIndex = j;
                }
            }
            if (newIndex != -1) {
                moved = true;
                clusterIndices[i] = newIndex;
            }
        }
        if (!moved && iteration != 0) {
            break;
        }

        std::vector<double> sumL(clusterCount, 0.0);
        std::vector<double> sumA(clusterCount, 0.0);
        std::vector<double> sumB(clusterCount, 0.0);
        std::fill(pixelCountSums.begin(), pixelCountSums.end(), 0);
        for (size_t i = 0; i < points.size(); ++i) {
            const int index = clusterIndices[i];
            const int count = counts[i];
            pixelCountSums[index] += count;
            sumL[index] += points[i].l * count;
            sumA[index] += points[i].a * count;
            sumB[index] += points[i].b * count;
        }
        for (int i = 0; i < clusterCount; ++i) {
            const int count = pixelCountSums[i];
            if (count == 0) {
                clusters[i] = {};
                continue;
            }
            clusters[i] = {sumL[i] / count, sumA[i] / count, sumB[i] / count};
        }
    }

    std::unordered_map<QRgb, int> result;
    for (int i = 0; i < clusterCount; ++i) {
        const int count = pixelCountSums[i];
        if (count == 0) {
            continue;
        }
        result[argbFromLab(clusters[i])] += count;
    }
    return result;
}

QList<QRgb> score(const std::unordered_map<QRgb, int> &population, int desired, bool filter)
{
    constexpr double kTargetChroma = 48.0;
    constexpr double kWeightProportion = 0.7;
    constexpr double kWeightChromaAbove = 0.3;
    constexpr double kWeightChromaBelow = 0.1;
    constexpr double kCutoffChroma = 5.0;
    constexpr double kCutoffExcitedProportion = 0.01;

    struct Candidate {
        QRgb argb;
        HueChroma cam;
        double score = 0.0;
    };
    std::vector<Candidate> colours;
    std::array<double, 360> huePopulation{};
    double populationSum = 0.0;
    for (const auto &[argb, count] : population) {
        const HueChroma cam = hueChroma(argb);
        colours.push_back({argb, cam});
        huePopulation[sanitizeDegrees(int(std::floor(cam.hue)))] += count;
        populationSum += count;
    }
    if (populationSum <= 0.0) {
        return {};
    }

    std::array<double, 360> excited{};
    for (int hue = 0; hue < 360; ++hue) {
        const double proportion = huePopulation[hue] / populationSum;
        for (int i = hue - 14; i < hue + 16; ++i) {
            excited[sanitizeDegrees(i)] += proportion;
        }
    }

    std::vector<Candidate> scored;
    for (Candidate &candidate : colours) {
        const double proportion = excited[sanitizeDegrees(int(std::round(candidate.cam.hue)))];
        if (filter && (candidate.cam.chroma < kCutoffChroma || proportion <= kCutoffExcitedProportion)) {
            continue;
        }
        const double proportionScore = proportion * 100.0 * kWeightProportion;
        const double chromaWeight = candidate.cam.chroma < kTargetChroma ? kWeightChromaBelow : kWeightChromaAbove;
        candidate.score = proportionScore + (candidate.cam.chroma - kTargetChroma) * chromaWeight;
        scored.push_back(candidate);
    }
    std::stable_sort(scored.begin(), scored.end(), [](const Candidate &a, const Candidate &b) {
        return a.score > b.score;
    });

    std::vector<Candidate> chosen;
    for (int difference = 90; difference >= 15; --difference) {
        chosen.clear();
        for (const Candidate &candidate : scored) {
            const bool duplicate = std::any_of(chosen.begin(), chosen.end(), [&](const Candidate &other) {
                return differenceDegrees(candidate.cam.hue, other.cam.hue) < difference;
            });
            if (!duplicate) {
                chosen.push_back(candidate);
            }
            if (int(chosen.size()) >= desired) {
                break;
            }
        }
        if (int(chosen.size()) >= desired) {
            break;
        }
    }

    QList<QRgb> result;
    for (const Candidate &candidate : chosen) {
        result.append(candidate.argb);
    }
    return result;
}
}

HueChroma hueChroma(QRgb argb)
{
    const Viewing &vc = viewing();
    const auto xyz = xyzFromArgb(argb);
    std::array<double, 3> adapted;
    for (int i = 0; i < 3; ++i) {
        const double cone = kToCam16[i][0] * xyz[0] + kToCam16[i][1] * xyz[1] + kToCam16[i][2] * xyz[2];
        const double discounted = vc.rgbD[i] * cone;
        const double af = std::pow(vc.fl * std::abs(discounted) / 100.0, 0.42);
        adapted[i] = (discounted < 0.0 ? -1.0 : discounted > 0.0 ? 1.0 : 0.0) * 400.0 * af / (af + 27.13);
    }
    const double a = (11.0 * adapted[0] - 12.0 * adapted[1] + adapted[2]) / 11.0;
    const double b = (adapted[0] + adapted[1] - 2.0 * adapted[2]) / 9.0;
    const double u = (20.0 * adapted[0] + 20.0 * adapted[1] + 21.0 * adapted[2]) / 20.0;
    const double p2 = (40.0 * adapted[0] + 20.0 * adapted[1] + adapted[2]) / 20.0;
    const double hue = sanitizeDegrees(std::atan2(b, a) * 180.0 / kPi);
    const double ac = p2 * vc.nbb;
    const double j = 100.0 * std::pow(ac / vc.aw, vc.c * vc.z);
    const double huePrime = hue < 20.14 ? hue + 360.0 : hue;
    const double eHue = 0.25 * (std::cos(huePrime * kPi / 180.0 + 2.0) + 3.8);
    const double p1 = 50000.0 / 13.0 * eHue * vc.nc * vc.ncb;
    const double t = p1 * std::sqrt(a * a + b * b) / (u + 0.305);
    const double alpha = std::pow(t, 0.9) * std::pow(1.64 - std::pow(0.29, vc.n), 0.73);
    return {hue, alpha * std::sqrt(j / 100.0)};
}

QList<QRgb> seeds(const QImage &source, int desired)
{
    if (source.isNull()) {
        return {};
    }
    QImage image = source.convertToFormat(QImage::Format_ARGB32);
    constexpr double kMaxArea = 112.0 * 112.0;
    const double area = double(image.width()) * image.height();
    if (area > kMaxArea) {
        const double factor = std::sqrt(kMaxArea / area);
        image = image.scaled(std::max(1, int(image.width() * factor)), std::max(1, int(image.height() * factor)), Qt::IgnoreAspectRatio,
                             Qt::SmoothTransformation);
    }
    std::vector<QRgb> pixels;
    pixels.reserve(size_t(image.width()) * image.height());
    for (int y = 0; y < image.height(); ++y) {
        const auto *line = reinterpret_cast<const QRgb *>(image.constScanLine(y));
        for (int x = 0; x < image.width(); ++x) {
            if (qAlpha(line[x]) == 255) {
                pixels.push_back(line[x] | 0xff000000u);
            }
        }
    }
    const auto population = quantizeWsmeans(pixels, quantizeWu(pixels, 128), 128);
    QList<QRgb> result = score(population, desired, true);
    if (result.isEmpty()) {
        result = score(population, 1, false);
    }
    return result;
}

QList<QRgb> seedsFromFile(const QString &path, int desired)
{
    QImageReader reader(path);
    const QSize size = reader.size();
    if (size.isValid() && double(size.width()) * size.height() > 448.0 * 448.0) {
        const double factor = std::sqrt(448.0 * 448.0 / (double(size.width()) * size.height()));
        reader.setScaledSize(QSize(std::max(1, int(size.width() * factor)), std::max(1, int(size.height() * factor))));
    }
    return seeds(reader.read(), desired);
}
}
