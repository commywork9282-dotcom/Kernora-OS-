# Source (Apache-2.0): https://github.com/androidx/androidx
# graphics/graphics-shapes/.../RoundedPolygon.kt, Shapes.kt, Cubic.kt
# compose/material3/material3/.../MaterialShapes.kt

from __future__ import annotations

import math
from dataclasses import dataclass

DISTANCE_EPSILON = 1e-4


@dataclass(frozen=True)
class P:
    x: float
    y: float

    def __add__(self, o: "P") -> "P":
        return P(self.x + o.x, self.y + o.y)

    def __sub__(self, o: "P") -> "P":
        return P(self.x - o.x, self.y - o.y)

    def __mul__(self, k: float) -> "P":
        return P(self.x * k, self.y * k)

    def __truediv__(self, k: float) -> "P":
        return P(self.x / k, self.y / k)

    def length(self) -> float:
        return math.hypot(self.x, self.y)

    def direction(self) -> "P":
        d = self.length()
        return P(0.0, 0.0) if d == 0 else self / d

    def dot(self, o: "P") -> float:
        return self.x * o.x + self.y * o.y

    def rotate90(self) -> "P":
        return P(-self.y, self.x)


def interpolate(a: P, b: P, t: float) -> P:
    return a + (b - a) * t


@dataclass(frozen=True)
class Rounding:
    radius: float = 0.0
    smoothing: float = 0.0


UNROUNDED = Rounding()


Cubic = tuple[P, P, P, P]


def straight_line(a: P, b: P) -> Cubic:
    return (a, interpolate(a, b, 1 / 3), interpolate(a, b, 2 / 3), b)


def circular_arc(center: P, p0: P, p1: P) -> Cubic:
    p0d = (p0 - center).direction()
    p1d = (p1 - center).direction()
    r0 = p0d.rotate90()
    r1 = p1d.rotate90()
    clockwise = r0.dot(p1 - center) >= 0
    cosa = p0d.dot(p1d)
    if cosa > 0.999:
        return straight_line(p0, p1)
    k = ((p0 - center).length() * 4 / 3
         * (math.sqrt(2 * (1 - cosa)) - math.sqrt(1 - cosa * cosa)) / (1 - cosa)
         * (1 if clockwise else -1))
    return (p0, p0 + r0 * k, p1 - r1 * k, p1)


def reverse(c: Cubic) -> Cubic:
    return (c[3], c[2], c[1], c[0])


def zero_length(c: Cubic) -> bool:
    return (abs(c[0].x - c[3].x) < DISTANCE_EPSILON
            and abs(c[0].y - c[3].y) < DISTANCE_EPSILON)


class RoundedCorner:
    def __init__(self, p0: P, p1: P, p2: P, rounding: Rounding) -> None:
        self.p0, self.p1, self.p2 = p0, p1, p2
        v01 = p0 - p1
        v21 = p2 - p1
        d01 = v01.length()
        d21 = v21.length()
        if d01 > 0 and d21 > 0:
            self.d1 = v01 / d01
            self.d2 = v21 / d21
            self.radius = rounding.radius
            self.smoothing = rounding.smoothing
            self.cos = self.d1.dot(self.d2)
            self.sin = math.sqrt(max(0.0, 1 - self.cos * self.cos))
            self.expected_round_cut = (
                self.radius * (self.cos + 1) / self.sin if self.sin > 1e-3 else 0.0
            )
        else:
            self.d1 = self.d2 = P(0, 0)
            self.radius = self.smoothing = self.cos = self.sin = 0.0
            self.expected_round_cut = 0.0

    @property
    def expected_cut(self) -> float:
        return (1 + self.smoothing) * self.expected_round_cut

    def _actual_smoothing(self, allowed_cut: float) -> float:
        if allowed_cut > self.expected_cut:
            return self.smoothing
        if allowed_cut > self.expected_round_cut:
            return (self.smoothing * (allowed_cut - self.expected_round_cut)
                    / (self.expected_cut - self.expected_round_cut))
        return 0.0

    def cubics(self, allowed_cut0: float, allowed_cut1: float) -> list[Cubic]:
        allowed_cut = min(allowed_cut0, allowed_cut1)
        if (self.expected_round_cut < DISTANCE_EPSILON or allowed_cut < DISTANCE_EPSILON
                or self.radius < DISTANCE_EPSILON):
            return [straight_line(self.p1, self.p1)]
        actual_round_cut = min(allowed_cut, self.expected_round_cut)
        smoothing0 = self._actual_smoothing(allowed_cut0)
        smoothing1 = self._actual_smoothing(allowed_cut1)
        actual_r = self.radius * actual_round_cut / self.expected_round_cut
        center_distance = math.hypot(actual_r, actual_round_cut)
        center = self.p1 + ((self.d1 + self.d2) / 2).direction() * center_distance
        circle0 = self.p1 + self.d1 * actual_round_cut
        circle2 = self.p1 + self.d2 * actual_round_cut
        flank0 = self._flanking(actual_round_cut, smoothing0, self.p1, self.p0,
                                circle0, circle2, center, actual_r)
        flank2 = reverse(self._flanking(actual_round_cut, smoothing1, self.p1, self.p2,
                                        circle2, circle0, center, actual_r))
        return [flank0, circular_arc(center, flank0[3], flank2[0]), flank2]

    @staticmethod
    def _flanking(round_cut: float, smoothing: float, corner: P, side_start: P,
                  circle_hit: P, other_circle_hit: P, center: P, radius: float) -> Cubic:
        side_direction = (side_start - corner).direction()
        curve_start = corner + side_direction * round_cut * (1 + smoothing)
        p = interpolate(circle_hit, (circle_hit + other_circle_hit) / 2, smoothing)
        curve_end = center + (p - center).direction() * radius
        tangent = (curve_end - center).rotate90()
        anchor_end = _line_intersection(side_start, side_direction, curve_end, tangent) or circle_hit
        anchor_start = (curve_start + anchor_end * 2) / 3
        return (curve_start, anchor_start, anchor_end, curve_end)


def _line_intersection(p0: P, d0: P, p1: P, d1: P) -> P | None:
    rotated = d1.rotate90()
    den = d0.dot(rotated)
    if abs(den) < DISTANCE_EPSILON:
        return None
    num = (p1 - p0).dot(rotated)
    if abs(den) < DISTANCE_EPSILON * abs(num):
        return None
    return p0 + d0 * (num / den)


def rounded_polygon(vertices: list[P], rounding: Rounding = UNROUNDED,
                    per_vertex: list[Rounding] | None = None) -> list[Cubic]:
    n = len(vertices)
    corners = [
        RoundedCorner(vertices[(i - 1) % n], vertices[i], vertices[(i + 1) % n],
                      per_vertex[i] if per_vertex else rounding)
        for i in range(n)
    ]
    cut_adjusts = []
    for i in range(n):
        expected_round_cut = corners[i].expected_round_cut + corners[(i + 1) % n].expected_round_cut
        expected_cut = corners[i].expected_cut + corners[(i + 1) % n].expected_cut
        side = (vertices[i] - vertices[(i + 1) % n]).length()
        if expected_round_cut > side:
            cut_adjusts.append((side / expected_round_cut, 0.0))
        elif expected_cut > side:
            cut_adjusts.append((1.0, (side - expected_round_cut) / (expected_cut - expected_round_cut)))
        else:
            cut_adjusts.append((1.0, 1.0))

    corner_cubics: list[list[Cubic]] = []
    for i in range(n):
        allowed = []
        for delta in (0, 1):
            round_ratio, cut_ratio = cut_adjusts[(i + n - 1 + delta) % n]
            allowed.append(corners[i].expected_round_cut * round_ratio
                           + (corners[i].expected_cut - corners[i].expected_round_cut) * cut_ratio)
        corner_cubics.append(corners[i].cubics(allowed[0], allowed[1]))

    outline: list[Cubic] = []
    for i in range(n):
        outline.extend(corner_cubics[i])
        outline.append(straight_line(corner_cubics[i][-1][3], corner_cubics[(i + 1) % n][0][0]))
    return [c for c in outline if not zero_length(c)]


def star(points_per_radius: int, inner_radius: float, rounding: Rounding) -> list[P]:
    vertices = []
    for i in range(points_per_radius):
        a = math.pi / points_per_radius * 2 * i
        vertices.append(P(math.cos(a), math.sin(a)))
        a = math.pi / points_per_radius * (2 * i + 1)
        vertices.append(P(inner_radius * math.cos(a), inner_radius * math.sin(a)))
    return vertices


def regular(n: int, radius: float = 1.0) -> list[P]:
    return [P(radius * math.cos(2 * math.pi * i / n), radius * math.sin(2 * math.pi * i / n))
            for i in range(n)]


def rotate(points: list[P], degrees: float, center: P = P(0, 0)) -> list[P]:
    a = math.radians(degrees)
    c, s = math.cos(a), math.sin(a)
    out = []
    for p in points:
        o = p - center
        out.append(P(o.x * c - o.y * s, o.x * s + o.y * c) + center)
    return out


def transform_cubics(cubics: list[Cubic], f) -> list[Cubic]:
    return [tuple(f(p) for p in c) for c in cubics]  # type: ignore[return-value]


def custom_polygon(points: list[tuple[float, float, Rounding]], reps: int,
                   mirroring: bool = False, center: P = P(0.5, 0.5)) -> list[Cubic]:
    pts = [P(x, y) for x, y, _ in points]
    rounds = [r for _, _, r in points]
    out_p: list[P] = []
    out_r: list[Rounding] = []
    if mirroring:
        angles = [math.degrees(math.atan2((p - center).y, (p - center).x)) for p in pts]
        distances = [(p - center).length() for p in pts]
        actual = reps * 2
        section = 360 / actual
        for it in range(actual):
            for index in range(len(pts)):
                i = index if it % 2 == 0 else len(pts) - 1 - index
                if i > 0 or it % 2 == 0:
                    a = section * it + (angles[i] if it % 2 == 0
                                        else section - angles[i] + 2 * angles[0])
                    r = math.radians(a)
                    out_p.append(P(math.cos(r), math.sin(r)) * distances[i] + center)
                    out_r.append(rounds[i])
    else:
        np_ = len(pts)
        for it in range(np_ * reps):
            out_p.append(rotate([pts[it % np_]], (it // np_) * 360 / reps, center)[0])
            out_r.append(rounds[it % np_])
    return rounded_polygon(out_p, per_vertex=out_r)


R = Rounding


def shape_definitions() -> dict[str, list[Cubic]]:
    r15, r20, r30, r50, r100 = R(0.15), R(0.2), R(0.3), R(0.5), R(1.0)

    def circle(n: int = 8) -> list[Cubic]:
        return rounded_polygon(regular(n, 1 / math.cos(math.pi / n)), rounding=R(1.0))

    def star_shape(points: int, inner: float, rounding: Rounding, rot: float = 0) -> list[Cubic]:
        return rounded_polygon(rotate(star(points, inner, rounding), rot), rounding=rounding)

    return {
        "circle": circle(10),
        "square": rounded_polygon([P(0.5, 0.5), P(-0.5, 0.5), P(-0.5, -0.5), P(0.5, -0.5)], rounding=r30),
        "pill": custom_polygon([(0.961, 0.039, R(0.426)), (1.001, 0.428, UNROUNDED),
                                (1.000, 0.609, R(1.0))], reps=2, mirroring=True),
        "oval": transform_cubics(circle(8), lambda p: rotate([P(p.x, p.y * 0.64)], -45)[0]),
        "arch": rounded_polygon(rotate(regular(4), -135), per_vertex=[r100, r100, r20, r20]),
        "triangle": rounded_polygon(rotate(regular(3), -90), rounding=r20),
        "sunny": star_shape(8, 0.8, r15),
        "verySunny": custom_polygon([(0.500, 1.080, R(0.085)), (0.358, 0.843, R(0.085))], reps=8),
        "cookie4": custom_polygon([(1.237, 1.236, R(0.258)), (0.500, 0.918, R(0.233))], reps=4),
        "cookie6": custom_polygon([(0.723, 0.884, R(0.394)), (0.500, 1.099, R(0.398))], reps=6),
        "cookie7": star_shape(7, 0.75, r50, -90),
        "cookie9": star_shape(9, 0.8, r50, -90),
        "cookie12": star_shape(12, 0.8, r50, -90),
        "clover4": custom_polygon([(0.500, 0.074, UNROUNDED), (0.725, -0.099, R(0.476))],
                                  reps=4, mirroring=True),
        "clover8": custom_polygon([(0.500, 0.036, UNROUNDED), (0.758, -0.101, R(0.209))], reps=8),
        "softBurst": custom_polygon([(0.193, 0.277, R(0.053)), (0.176, 0.055, R(0.053))], reps=10),
        "flower": custom_polygon([(0.370, 0.187, UNROUNDED), (0.416, 0.049, R(0.381)),
                                  (0.479, 0.001, R(0.095))], reps=8, mirroring=True),
        "puffy": transform_cubics(custom_polygon([
            (0.500, 0.053, UNROUNDED), (0.545, -0.040, R(0.405)), (0.670, -0.035, R(0.426)),
            (0.717, 0.066, R(0.574)), (0.722, 0.128, UNROUNDED), (0.777, 0.002, R(0.360)),
            (0.914, 0.149, R(0.660)), (0.926, 0.289, R(0.660)), (0.881, 0.346, UNROUNDED),
            (0.940, 0.344, R(0.126)), (1.003, 0.437, R(0.255))], reps=2, mirroring=True),
            lambda p: P(p.x, p.y * 0.742)),
        "puffyDiamond": custom_polygon([(0.870, 0.130, R(0.146)), (0.818, 0.357, UNROUNDED),
                                        (1.000, 0.332, R(0.853))], reps=4, mirroring=True),
        "ghostish": custom_polygon([(0.500, 0.0, R(1.0)), (1.0, 0.0, R(1.0)),
                                    (1.0, 1.140, R(0.254, 0.106)), (0.575, 0.906, R(0.253))],
                                   reps=1, mirroring=True),
        "gem": custom_polygon([(0.499, 1.023, R(0.241, 0.778)), (-0.005, 0.792, R(0.208)),
                               (0.073, 0.258, R(0.228)), (0.433, -0.000, R(0.491))],
                              reps=1, mirroring=True),
        "heart": custom_polygon([(0.500, 0.268, R(0.016)), (0.792, -0.066, R(0.958)),
                                 (1.064, 0.276, R(1.0)), (0.501, 0.946, R(0.129))],
                                reps=1, mirroring=True),
    }


def _point_on(c: Cubic, t: float) -> P:
    u = 1 - t
    return (c[0] * (u * u * u) + c[1] * (3 * u * u * t)
            + c[2] * (3 * u * t * t) + c[3] * (t * t * t))


def bounds(cubics: list[Cubic]) -> tuple[float, float, float, float]:
    xs, ys = [], []
    for c in cubics:
        for i in range(17):
            p = _point_on(c, i / 16)
            xs.append(p.x)
            ys.append(p.y)
    return min(xs), min(ys), max(xs), max(ys)


def normalized(cubics: list[Cubic]) -> list[Cubic]:
    x0, y0, x1, y1 = bounds(cubics)
    side = max(x1 - x0, y1 - y0)
    ox = (side - (x1 - x0)) / 2 - x0
    oy = (side - (y1 - y0)) / 2 - y0
    return transform_cubics(cubics, lambda p: P((p.x + ox) / side, (p.y + oy) / side))


def polar_radii(cubics: list[Cubic], samples: int) -> list[float]:
    tau = 2 * math.pi
    points = []
    for c in normalized(cubics):
        for i in range(64):
            p = _point_on(c, i / 64)
            points.append((math.atan2(p.y - 0.5, p.x - 0.5) % tau, math.hypot(p.x - 0.5, p.y - 0.5)))
    points.sort()
    ring = [(a - tau, r) for a, r in points[-2:]] + points + [(a + tau, r) for a, r in points[:2]]
    result = []
    j = 0
    for k in range(samples):
        angle = tau * k / samples
        while ring[j + 1][0] < angle:
            j += 1
        (a0, r0), (a1, r1) = ring[j], ring[j + 1]
        f = (angle - a0) / (a1 - a0) if a1 > a0 else 0.0
        result.append(round(r0 + (r1 - r0) * f, 4))
    return result


def svg_path(cubics: list[Cubic], scale: float = 1.0, digits: int = 4) -> str:
    def f(v: float) -> str:
        text = f"{v * scale:.{digits}f}".rstrip("0").rstrip(".")
        return text if text not in ("", "-0") else "0"

    parts = [f"M{f(cubics[0][0].x)} {f(cubics[0][0].y)}"]
    for c in cubics:
        parts.append(f"C{f(c[1].x)} {f(c[1].y)} {f(c[2].x)} {f(c[2].y)} {f(c[3].x)} {f(c[3].y)}")
    parts.append("Z")
    return "".join(parts)


def all_paths(scale: float = 1.0) -> dict[str, str]:
    return {name: svg_path(normalized(cubics), scale)
            for name, cubics in shape_definitions().items()}
