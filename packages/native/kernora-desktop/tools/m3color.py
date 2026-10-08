
from __future__ import annotations

import math


SRGB_TO_XYZ = (
    (0.41233895, 0.35762064, 0.18051042),
    (0.21263901, 0.71516868, 0.07219232),
    (0.01933082, 0.11919478, 0.95053215),
)

XYZ_TO_SRGB = (
    (3.2413774792388685, -1.5376652402851851, -0.49885366846268053),
    (-0.9691452513005321, 1.8758853451067872, 0.04156585616912061),
    (0.05562093689691305, -0.20395524564742123, 1.0571799111220335),
)

XYZ_TO_CAM16RGB = (
    (0.401288, 0.650173, -0.051461),
    (-0.250268, 1.204414, 0.045854),
    (-0.002079, 0.048952, 0.953127),
)

CAM16RGB_TO_XYZ = (
    (1.8620678, -1.0112547, 0.14918678),
    (0.38752654, 0.62144744, -0.00897398),
    (-0.01584150, -0.03412294, 1.0499644),
)

WHITE_POINT_D65 = (95.047, 100.0, 108.883)


def _matrix_multiply(row: tuple[float, float, float], matrix) -> list[float]:
    return [
        row[0] * matrix[i][0] + row[1] * matrix[i][1] + row[2] * matrix[i][2]
        for i in range(3)
    ]


def _signum(value: float) -> int:
    if value < 0:
        return -1
    if value > 0:
        return 1
    return 0


def _sanitize_degrees(degrees: float) -> float:
    degrees = degrees % 360.0
    if degrees < 0:
        degrees += 360.0
    return degrees


def _linearized(rgb_component: int) -> float:
    normalized = rgb_component / 255.0
    if normalized <= 0.040449936:
        return normalized / 12.92 * 100.0
    return math.pow((normalized + 0.055) / 1.055, 2.4) * 100.0


def _delinearized(rgb_component: float) -> int:
    normalized = rgb_component / 100.0
    if normalized <= 0.0031308:
        delinear = normalized * 12.92
    else:
        delinear = 1.055 * math.pow(normalized, 1.0 / 2.4) - 0.055
    return max(0, min(255, round(delinear * 255.0)))


def y_from_lstar(lstar: float) -> float:
    if lstar > 8.0:
        return 100.0 * math.pow((lstar + 16.0) / 116.0, 3.0)
    return 100.0 * lstar / 903.2962962962963


def lstar_from_y(y: float) -> float:
    scaled = y / 100.0
    if scaled <= 216.0 / 24389.0:
        return scaled * 24389.0 / 27.0
    return 116.0 * math.pow(scaled, 1.0 / 3.0) - 16.0


def xyz_from_rgb(rgb: tuple[int, int, int]) -> list[float]:
    linear = (_linearized(rgb[0]), _linearized(rgb[1]), _linearized(rgb[2]))
    return _matrix_multiply(linear, SRGB_TO_XYZ)


def rgb_from_xyz(xyz) -> tuple[int, int, int]:
    linear = _matrix_multiply((xyz[0], xyz[1], xyz[2]), XYZ_TO_SRGB)
    return (
        _delinearized(linear[0]),
        _delinearized(linear[1]),
        _delinearized(linear[2]),
    )


def lstar_from_rgb(rgb: tuple[int, int, int]) -> float:
    return lstar_from_y(xyz_from_rgb(rgb)[1])


def rgb_from_lstar(lstar: float) -> tuple[int, int, int]:
    component = _delinearized(y_from_lstar(lstar))
    return (component, component, component)


class ViewingConditions:

    def __init__(
        self,
        white_point=WHITE_POINT_D65,
        adapting_luminance: float | None = None,
        background_lstar: float = 50.0,
        surround: float = 2.0,
        discounting_illuminant: bool = False,
    ) -> None:
        if adapting_luminance is None:
            adapting_luminance = (200.0 / math.pi) * y_from_lstar(50.0) / 100.0

        white = _matrix_multiply(
            (white_point[0], white_point[1], white_point[2]), XYZ_TO_CAM16RGB
        )
        background_lstar = max(0.1, background_lstar)

        f = 0.8 + surround / 10.0
        if f >= 0.9:
            c = _lerp(0.59, 0.69, (f - 0.9) * 10.0)
        else:
            c = _lerp(0.525, 0.59, (f - 0.8) * 10.0)

        if discounting_illuminant:
            d = 1.0
        else:
            d = f * (
                1.0
                - (1.0 / 3.6) * math.exp((-adapting_luminance - 42.0) / 92.0)
            )
        d = max(0.0, min(1.0, d))

        self.n = y_from_lstar(background_lstar) / white_point[1]
        self.aw: float
        self.nbb = 0.725 / math.pow(self.n, 0.2)
        self.ncb = self.nbb
        self.c = c
        self.nc = f
        self.rgb_d = [
            d * (100.0 / white[0]) + 1.0 - d,
            d * (100.0 / white[1]) + 1.0 - d,
            d * (100.0 / white[2]) + 1.0 - d,
        ]

        k = 1.0 / (5.0 * adapting_luminance + 1.0)
        k4 = k * k * k * k
        k4f = 1.0 - k4
        self.fl = k4 * adapting_luminance + 0.1 * k4f * k4f * math.pow(
            5.0 * adapting_luminance, 1.0 / 3.0
        )
        self.fl_root = math.pow(self.fl, 0.25)
        self.z = 1.48 + math.sqrt(self.n)

        rgb_a_factors = [
            math.pow(self.fl * self.rgb_d[i] * white[i] / 100.0, 0.42)
            for i in range(3)
        ]
        rgb_a = [
            400.0 * factor / (factor + 27.13) for factor in rgb_a_factors
        ]
        self.aw = (
            (40.0 * rgb_a[0] + 20.0 * rgb_a[1] + rgb_a[2]) / 20.0 * self.nbb
        )


def _lerp(start: float, stop: float, amount: float) -> float:
    return start + (stop - start) * amount


DEFAULT_VIEWING_CONDITIONS = ViewingConditions()


class Cam16:
    __slots__ = ("hue", "chroma", "j", "m", "astar", "bstar", "jstar")

    def __init__(self, hue: float, chroma: float, j: float, m: float) -> None:
        self.hue = hue
        self.chroma = chroma
        self.j = j
        self.m = m
        self.jstar = (1.0 + 100.0 * 0.007) * j / (1.0 + 0.007 * j)
        mstar = 1.0 / 0.0228 * math.log1p(0.0228 * m)
        hue_radians = hue * math.pi / 180.0
        self.astar = mstar * math.cos(hue_radians)
        self.bstar = mstar * math.sin(hue_radians)

    def distance(self, other: "Cam16") -> float:
        d_j = self.jstar - other.jstar
        d_a = self.astar - other.astar
        d_b = self.bstar - other.bstar
        d_e_prime = math.sqrt(d_j * d_j + d_a * d_a + d_b * d_b)
        return 1.41 * math.pow(d_e_prime, 0.63)


def cam16_from_xyz(xyz, vc: ViewingConditions = DEFAULT_VIEWING_CONDITIONS) -> Cam16:
    cone = _matrix_multiply((xyz[0], xyz[1], xyz[2]), XYZ_TO_CAM16RGB)
    discounted = [vc.rgb_d[i] * cone[i] for i in range(3)]

    adapted = []
    for value in discounted:
        af = math.pow(vc.fl * abs(value) / 100.0, 0.42)
        adapted.append(_signum(value) * 400.0 * af / (af + 27.13))

    r_a, g_a, b_a = adapted
    a = (11.0 * r_a + -12.0 * g_a + b_a) / 11.0
    b = (r_a + g_a - 2.0 * b_a) / 9.0
    u = (20.0 * r_a + 20.0 * g_a + 21.0 * b_a) / 20.0
    p2 = (40.0 * r_a + 20.0 * g_a + b_a) / 20.0

    atan_degrees = math.atan2(b, a) * 180.0 / math.pi
    hue = _sanitize_degrees(atan_degrees)
    hue_radians = hue * math.pi / 180.0

    ac = p2 * vc.nbb
    j = 100.0 * math.pow(ac / vc.aw, vc.c * vc.z)

    hue_prime = hue + 360.0 if hue < 20.14 else hue
    e_hue = 0.25 * (math.cos(hue_prime * math.pi / 180.0 + 2.0) + 3.8)
    p1 = 50000.0 / 13.0 * e_hue * vc.nc * vc.ncb
    t = p1 * math.sqrt(a * a + b * b) / (u + 0.305)
    alpha = math.pow(t, 0.9) * math.pow(
        1.64 - math.pow(0.29, vc.n), 0.73
    )
    chroma = alpha * math.sqrt(j / 100.0)
    m = chroma * vc.fl_root
    del hue_radians
    return Cam16(hue, chroma, j, m)


def cam16_from_rgb(
    rgb: tuple[int, int, int], vc: ViewingConditions = DEFAULT_VIEWING_CONDITIONS
) -> Cam16:
    return cam16_from_xyz(xyz_from_rgb(rgb), vc)


def xyz_from_jch(
    j: float,
    chroma: float,
    hue: float,
    vc: ViewingConditions = DEFAULT_VIEWING_CONDITIONS,
):
    if chroma == 0.0 or j == 0.0:
        alpha = 0.0
    else:
        alpha = chroma / math.sqrt(j / 100.0)

    t = math.pow(alpha / math.pow(1.64 - math.pow(0.29, vc.n), 0.73), 1.0 / 0.9)
    h_rad = hue * math.pi / 180.0
    e_hue = 0.25 * (math.cos(h_rad + 2.0) + 3.8)
    ac = vc.aw * math.pow(j / 100.0, 1.0 / vc.c / vc.z)
    p1 = e_hue * (50000.0 / 13.0) * vc.nc * vc.ncb
    p2 = ac / vc.nbb

    h_sin = math.sin(h_rad)
    h_cos = math.cos(h_rad)
    gamma = (
        23.0
        * (p2 + 0.305)
        * t
        / (23.0 * p1 + 11.0 * t * h_cos + 108.0 * t * h_sin)
    )
    a = gamma * h_cos
    b = gamma * h_sin

    r_a = (460.0 * p2 + 451.0 * a + 288.0 * b) / 1403.0
    g_a = (460.0 * p2 - 891.0 * a - 261.0 * b) / 1403.0
    b_a = (460.0 * p2 - 220.0 * a - 6300.0 * b) / 1403.0

    cone = []
    for value in (r_a, g_a, b_a):
        base = max(0.0, 27.13 * abs(value) / (400.0 - abs(value)))
        cone.append(
            _signum(value) * (100.0 / vc.fl) * math.pow(base, 1.0 / 0.42)
        )

    undiscounted = tuple(cone[i] / vc.rgb_d[i] for i in range(3))
    return _matrix_multiply(undiscounted, CAM16RGB_TO_XYZ)


def rgb_from_jch(
    j: float,
    chroma: float,
    hue: float,
    vc: ViewingConditions = DEFAULT_VIEWING_CONDITIONS,
) -> tuple[int, int, int]:
    return rgb_from_xyz(xyz_from_jch(j, chroma, hue, vc))


_CHROMA_SEARCH_ENDPOINT = 0.4
_DE_MAX = 1.0
_DL_MAX = 0.2


def _find_cam_by_j(hue: float, chroma: float, tone: float) -> Cam16 | None:
    low = 0.0
    high = 100.0
    best_d_l = 1000.0
    best_d_e = 1000.0
    best_cam: Cam16 | None = None

    while abs(low - high) > _DL_MAX:
        mid = low + (high - low) / 2.0
        clipped = rgb_from_jch(mid, chroma, hue)
        clipped_lstar = lstar_from_rgb(clipped)
        d_l = abs(tone - clipped_lstar)

        if d_l < _DL_MAX:
            cam_clipped = cam16_from_rgb(clipped)
            requested = _cam_from_jch(cam_clipped.j, cam_clipped.chroma, hue)
            d_e = cam_clipped.distance(requested)
            if d_e <= _DE_MAX and d_e <= best_d_e:
                best_d_l = d_l
                best_d_e = d_e
                best_cam = cam_clipped

        if best_d_l == 0.0 and best_d_e == 0.0:
            break

        if clipped_lstar < tone:
            low = mid
        else:
            high = mid

    return best_cam


def _cam_from_jch(j: float, chroma: float, hue: float) -> Cam16:
    vc = DEFAULT_VIEWING_CONDITIONS
    q = (
        (4.0 / vc.c)
        * math.sqrt(j / 100.0)
        * (vc.aw + 4.0)
        * vc.fl_root
    )
    del q
    m = chroma * vc.fl_root
    return Cam16(hue, chroma, j, m)


def rgb_from_hct(hue: float, chroma: float, tone: float) -> tuple[int, int, int]:
    if chroma < 1.0 or round(tone) <= 0 or round(tone) >= 100:
        return rgb_from_lstar(tone)

    hue = _sanitize_degrees(hue)
    high = chroma
    mid = chroma
    low = 0.0
    first_loop = True
    answer: Cam16 | None = None

    while abs(low - high) >= _CHROMA_SEARCH_ENDPOINT:
        possible = _find_cam_by_j(hue, mid, tone)
        if first_loop:
            if possible is not None:
                return rgb_from_jch(possible.j, possible.chroma, possible.hue)
            first_loop = False
            mid = low + (high - low) / 2.0
            continue

        if possible is None:
            high = mid
        else:
            answer = possible
            low = mid
        mid = low + (high - low) / 2.0

    if answer is None:
        return rgb_from_lstar(tone)
    return rgb_from_jch(answer.j, answer.chroma, answer.hue)


class Hct:

    __slots__ = ("hue", "chroma", "tone")

    def __init__(self, hue: float, chroma: float, tone: float) -> None:
        self.hue = hue
        self.chroma = chroma
        self.tone = tone

    @staticmethod
    def from_rgb(rgb: tuple[int, int, int]) -> "Hct":
        cam = cam16_from_rgb(rgb)
        return Hct(cam.hue, cam.chroma, lstar_from_rgb(rgb))

    @staticmethod
    def from_hex(value: str) -> "Hct":
        return Hct.from_rgb(rgb_from_hex(value))

    def to_rgb(self) -> tuple[int, int, int]:
        return rgb_from_hct(self.hue, self.chroma, self.tone)


class TonalPalette:

    def __init__(self, hue: float, chroma: float) -> None:
        self.hue = hue
        self.chroma = chroma
        self._cache: dict[float, tuple[int, int, int]] = {}

    @staticmethod
    def from_hct(hct: Hct) -> "TonalPalette":
        return TonalPalette(hct.hue, hct.chroma)

    def tone(self, tone: float) -> tuple[int, int, int]:
        if tone not in self._cache:
            self._cache[tone] = rgb_from_hct(self.hue, self.chroma, tone)
        return self._cache[tone]

    def hex(self, tone: float) -> str:
        return hex_from_rgb(self.tone(tone))


def rgb_from_hex(value: str) -> tuple[int, int, int]:
    text = value.lstrip("#")
    if len(text) != 6:
        raise ValueError(f"expected a #rrggbb colour, got {value!r}")
    return (int(text[0:2], 16), int(text[2:4], 16), int(text[4:6], 16))


def hex_from_rgb(rgb: tuple[int, int, int]) -> str:
    return "#%02x%02x%02x" % rgb


_HUES = (0.0, 41.0, 61.0, 101.0, 131.0, 181.0, 251.0, 301.0, 360.0)
_SECONDARY_ROTATIONS = (18.0, 15.0, 10.0, 12.0, 15.0, 18.0, 15.0, 12.0, 12.0)
_TERTIARY_ROTATIONS = (35.0, 30.0, 20.0, 25.0, 30.0, 35.0, 30.0, 25.0, 25.0)


def _rotated_hue(source: Hct, rotations) -> float:
    source_hue = source.hue
    if len(rotations) == 1:
        return _sanitize_degrees(source_hue + rotations[0])
    for i in range(len(_HUES) - 1):
        this_hue = _HUES[i]
        next_hue = _HUES[i + 1]
        if this_hue < source_hue < next_hue:
            return _sanitize_degrees(source_hue + rotations[i])
    return source_hue


class Scheme:

    def __init__(self, seed: str, dark: bool, contrast_boost: float = 0.0, chroma: float | None = None) -> None:
        self.seed = seed
        self.dark = dark
        source = Hct.from_hex(seed)
        self.source = source

        primary = max(source.chroma, 48.0) if chroma is None else chroma
        self.primary = TonalPalette(source.hue, primary)
        self.secondary = TonalPalette(
            _rotated_hue(source, _SECONDARY_ROTATIONS), 16.0 if chroma is None else min(16.0, chroma / 2)
        )
        self.tertiary = TonalPalette(
            _rotated_hue(source, _TERTIARY_ROTATIONS), 32.0 if chroma is None else min(32.0, chroma)
        )
        self.neutral = TonalPalette(source.hue, 4.0 if chroma is None else min(4.0, chroma / 4))
        self.neutral_variant = TonalPalette(source.hue, 8.0 if chroma is None else min(8.0, chroma / 2))
        self.error = TonalPalette(25.0, 84.0)
        self._boost = contrast_boost

    def _t(self, palette: TonalPalette, dark_tone: float, light_tone: float) -> str:
        tone = dark_tone if self.dark else light_tone
        if self._boost:
            tone = max(0.0, min(100.0, tone + self._boost * (1 if self.dark else -1)))
        return palette.hex(tone)

    def roles(self) -> dict[str, str]:
        p, s, t = self.primary, self.secondary, self.tertiary
        n, nv, e = self.neutral, self.neutral_variant, self.error
        return {
            "primary": self._t(p, 80, 40),
            "onPrimary": self._t(p, 20, 100),
            "primaryContainer": self._t(p, 30, 90),
            "onPrimaryContainer": self._t(p, 90, 10),
            "inversePrimary": self._t(p, 40, 80),
            "primaryFixed": p.hex(90),
            "onPrimaryFixed": p.hex(10),
            "secondary": self._t(s, 80, 40),
            "onSecondary": self._t(s, 20, 100),
            "secondaryContainer": self._t(s, 30, 90),
            "onSecondaryContainer": self._t(s, 90, 10),
            "tertiary": self._t(t, 80, 40),
            "onTertiary": self._t(t, 20, 100),
            "tertiaryContainer": self._t(t, 30, 90),
            "onTertiaryContainer": self._t(t, 90, 10),
            "error": self._t(e, 80, 40),
            "onError": self._t(e, 20, 100),
            "errorContainer": self._t(e, 30, 90),
            "onErrorContainer": self._t(e, 90, 10),
            "background": self._t(n, 6, 98),
            "onBackground": self._t(n, 90, 10),
            "surface": self._t(n, 6, 98),
            "onSurface": self._t(n, 90, 10),
            "surfaceDim": self._t(n, 6, 87),
            "surfaceBright": self._t(n, 24, 98),
            "surfaceContainerLowest": self._t(n, 4, 100),
            "surfaceContainerLow": self._t(n, 10, 96),
            "surfaceContainer": self._t(n, 12, 94),
            "surfaceContainerHigh": self._t(n, 17, 92),
            "surfaceContainerHighest": self._t(n, 22, 90),
            "surfaceVariant": self._t(nv, 30, 90),
            "onSurfaceVariant": self._t(nv, 80, 30),
            "outline": self._t(nv, 60, 50),
            "outlineVariant": self._t(nv, 30, 80),
            "inverseSurface": self._t(n, 90, 20),
            "inverseOnSurface": self._t(n, 20, 95),
            "scrim": "#000000",
            "shadow": "#000000",
            "positive": TonalPalette(145.0, 50.0).hex(80 if self.dark else 40),
            "negative": self._t(e, 80, 40),
            "neutralYellow": TonalPalette(75.0, 60.0).hex(80 if self.dark else 40),
        }
