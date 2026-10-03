
from __future__ import annotations

import os

import m3color

SEED = "#ff6a1e"

SCHEME_NAME = "Kernora"


GENERATIONS = ("md1", "md2", "md3")
DEFAULT_GENERATION = "md3"
GENERATION = os.environ.get("KERNORA_GENERATION", DEFAULT_GENERATION)
if GENERATION not in GENERATIONS:
    raise SystemExit(f"KERNORA_GENERATION must be one of {GENERATIONS}, not {GENERATION!r}")

GENERATION_SUFFIX = {"md1": "MD1", "md2": "MD2", "md3": ""}
GENERATION_TITLE = {"md1": "Material Design 1", "md2": "Material Design 2", "md3": "Material 3"}
GENERATION_LABEL = {"md1": " MD1", "md2": " MD2", "md3": ""}

CLASSIC_ACCENT_HUE = 305.0


def _hct(hue: float, chroma: float, tone: float) -> str:
    return m3color.hex_from_rgb(m3color.rgb_from_hct(hue, chroma, tone))


def _blend(base: str, over: str, amount: float) -> str:
    a = m3color.rgb_from_hex(base)
    b = m3color.rgb_from_hex(over)
    return m3color.hex_from_rgb(tuple(round(a[i] + (b[i] - a[i]) * amount) for i in range(3)))


def _classic_scheme(generation: str, dark: bool) -> dict[str, str]:
    seed = m3color.Hct.from_hex(SEED)
    hue, chroma = seed.hue, seed.chroma
    accent = CLASSIC_ACCENT_HUE
    tonal = m3color.Scheme(SEED, dark=dark).roles()

    if generation == "md1":
        if dark:
            surfaces = ("#303030", "#212121", "#383838", "#424242", "#484848", "#505050")
            on_surface, on_variant = "#ffffff", "#b3b3b3"
            outline, outline_variant = "#8a8a8a", "#4f4f4f"
        else:
            surfaces = ("#fafafa", "#ffffff", "#ffffff", "#ffffff", "#f5f5f5", "#eeeeee")
            on_surface, on_variant = "#212121", "#757575"
            outline, outline_variant = "#bdbdbd", "#e0e0e0"
        primary = SEED
        on_primary = "#ffffff"
        secondary = _hct(accent, 80.0, 70.0 if dark else 55.0)
        on_secondary = "#000000" if dark else "#ffffff"
        selection = "#505050" if dark else "#e8e8e8"
        on_selection = SEED
        error, on_error = ("#ef5350", "#000000") if dark else ("#f44336", "#ffffff")
        inverse, on_inverse = "#323232", "#ffffff"
    else:
        if dark:
            base = "#121212"
            surfaces = (base, "#0b0b0b", _blend(base, "#ffffff", 0.05), _blend(base, "#ffffff", 0.07),
                        _blend(base, "#ffffff", 0.09), _blend(base, "#ffffff", 0.12))
            on_surface, on_variant = _blend(base, "#ffffff", 0.87), _blend(base, "#ffffff", 0.60)
            outline, outline_variant = _blend(base, "#ffffff", 0.38), _blend(base, "#ffffff", 0.12)
            primary = _hct(hue, min(chroma, 45.0), 80.0)
            on_primary = "#000000"
            secondary = _hct(accent, 40.0, 80.0)
            on_secondary = "#000000"
            selection = _blend(base, primary, 0.16)
            on_selection = primary
            error, on_error = "#cf6679", "#000000"
            inverse, on_inverse = _blend(base, "#ffffff", 0.87), base
        else:
            base = "#ffffff"
            surfaces = (base, "#ffffff", "#fafafa", "#f5f5f5", "#eeeeee", "#e8e8e8")
            on_surface, on_variant = _blend(base, "#000000", 0.87), _blend(base, "#000000", 0.60)
            outline, outline_variant = _blend(base, "#000000", 0.38), _blend(base, "#000000", 0.12)
            primary = _hct(hue, chroma, 45.0)
            on_primary = "#ffffff"
            secondary = _hct(accent, 60.0, 45.0)
            on_secondary = "#ffffff"
            selection = _blend(base, primary, 0.12)
            on_selection = _hct(hue, chroma, 35.0)
            error, on_error = "#b00020", "#ffffff"
            inverse, on_inverse = "#323232", "#ffffff"

    surface, lowest, low, container, high, highest = surfaces
    return {
        "primary": primary,
        "onPrimary": on_primary,
        "primaryContainer": _blend(surface, primary, 0.16 if dark else 0.12),
        "onPrimaryContainer": primary if dark else _hct(hue, chroma, 30.0),
        "inversePrimary": _hct(hue, chroma, 40.0 if dark else 80.0),
        "primaryFixed": _hct(hue, chroma, 90.0),
        "onPrimaryFixed": _hct(hue, chroma, 10.0),
        "secondary": secondary,
        "onSecondary": on_secondary,
        "secondaryContainer": selection,
        "onSecondaryContainer": on_selection,
        "tertiary": secondary,
        "onTertiary": on_secondary,
        "tertiaryContainer": _blend(surface, secondary, 0.16 if dark else 0.12),
        "onTertiaryContainer": secondary if dark else _hct(accent, 60.0, 30.0),
        "error": error,
        "onError": on_error,
        "errorContainer": _blend(surface, error, 0.16 if dark else 0.12),
        "onErrorContainer": error,
        "background": surface,
        "onBackground": on_surface,
        "surface": surface,
        "onSurface": on_surface,
        "surfaceDim": surface if dark else surfaces[5],
        "surfaceBright": highest if dark else "#ffffff",
        "surfaceContainerLowest": lowest,
        "surfaceContainerLow": low,
        "surfaceContainer": container,
        "surfaceContainerHigh": high,
        "surfaceContainerHighest": highest,
        "surfaceVariant": highest,
        "onSurfaceVariant": on_variant,
        "outline": outline,
        "outlineVariant": outline_variant,
        "inverseSurface": inverse,
        "inverseOnSurface": on_inverse,
        "scrim": "#000000",
        "shadow": "#000000",
        "positive": tonal["positive"],
        "negative": error,
        "neutralYellow": tonal["neutralYellow"],
    }


def scheme_id(dark: bool, generation: str | None = None) -> str:
    generation = generation or GENERATION
    return f"{SCHEME_NAME}{GENERATION_SUFFIX[generation]}{'Dark' if dark else 'Light'}"


def palette(generation: str, dark: bool) -> dict[str, str]:
    if generation == "md3":
        return m3color.Scheme(SEED, dark=dark).roles()
    return _classic_scheme(generation, dark)


def scheme(dark: bool) -> dict[str, str]:
    return palette(GENERATION, dark)


DARK = scheme(True)
LIGHT = scheme(False)


ACCENT_HUES = {
    "blue": 262.0,
    "teal": 192.0,
    "green": 142.0,
    "amber": 80.0,
    "rose": 12.0,
    "violet": 305.0,
}
ACCENT_CHROMA = 40.0


def _harmonized_hue(hue: float) -> float:
    seed = m3color.Hct.from_hex(SEED).hue
    difference = (seed - hue + 540.0) % 360.0 - 180.0
    rotation = max(-15.0, min(15.0, difference * 0.5))
    return (hue + rotation) % 360.0


def accents(dark: bool) -> list[tuple[str, str, str]]:
    result = []
    for name, hue in ACCENT_HUES.items():
        h = _harmonized_hue(hue)
        container = m3color.hex_from_rgb(m3color.rgb_from_hct(h, ACCENT_CHROMA, 30 if dark else 90))
        content = m3color.hex_from_rgb(m3color.rgb_from_hct(h, ACCENT_CHROMA * 0.5, 90 if dark else 10))
        result.append((name, container, content))
    return result


FULL = -1
CORNERS = {
    "dialog": (2, 4, 28),
    "sheet": (2, 16, 28),
    "card": (2, 8, 24),
    "cardInner": (2, 8, 6),
    "tile": (2, 8, 20),
    "listItem": (0, 4, 20),
    "button": (2, 4, FULL),
    "field": (2, 4, FULL),
    "chip": (FULL, FULL, 8),
    "menu": (2, 4, 12),
    "tooltip": (2, 4, 8),
    "image": (0, 4, 12),
    "indicator": (0, 4, FULL),
    "snackbar": (2, 4, 4),
    "fab": (FULL, FULL, 16),
    "panel": (0, 8, FULL),
    "window": (2, 8, 12),
}


def corner(kind: str, generation: str | None = None) -> int:
    return CORNERS[kind][GENERATIONS.index(generation or GENERATION)]


ELEVATION = {
    "md1": ((0, 0, 0.0), (3, 1, 0.24), (6, 3, 0.23), (20, 10, 0.19), (28, 14, 0.25), (38, 19, 0.30)),
    "md2": ((0, 0, 0.0), (3, 1, 0.20), (5, 2, 0.20), (10, 4, 0.20), (16, 6, 0.22), (24, 9, 0.24)),
    "md3": ((0, 0, 0.0), (2, 1, 0.15), (4, 2, 0.18), (8, 3, 0.20), (16, 5, 0.25), (28, 6, 0.45)),
}

ELEVATION_LEVEL = {
    "card": (1, 1, 0),
    "button": (2, 2, 0),
    "fab": (3, 3, 3),
    "field": (1, 1, 0),
    "menu": (3, 3, 2),
    "dialog": (5, 5, 3),
    "sheet": (4, 4, 5),
    "snackbar": (3, 3, 3),
    "panel": (3, 2, 2),
}

COMPONENT = {
    "md1": {"buttonCase": "upper", "control": "classic", "tile": "icon", "slabGap": 8},
    "md2": {"buttonCase": "upper", "control": "classic", "tile": "circle", "slabGap": 8},
    "md3": {"buttonCase": "none", "control": "m3", "tile": "tile", "slabGap": 2},
}

SHAPE = {
    "none": 0,
    "extraSmall": 4,
    "small": 8,
    "medium": 12,
    "large": 16,
    "largeIncreased": 20,
    "extraLarge": 28,
    "extraLargeIncreased": 32,
    "extraExtraLarge": 48,
    "full": 999,
}


TYPEFACE = "Roboto"
TYPEFACE_FALLBACK = "Noto Sans"

TYPE_SCALE = {
    "displayLarge": (57, 64, 400, -0.25),
    "displayMedium": (45, 52, 400, 0.0),
    "displaySmall": (36, 44, 400, 0.0),
    "headlineLarge": (32, 40, 400, 0.0),
    "headlineMedium": (28, 36, 400, 0.0),
    "headlineSmall": (24, 32, 400, 0.0),
    "titleLarge": (22, 28, 400, 0.0),
    "titleMedium": (16, 24, 500, 0.15),
    "titleSmall": (14, 20, 500, 0.1),
    "bodyLarge": (16, 24, 400, 0.5),
    "bodyMedium": (14, 20, 400, 0.25),
    "bodySmall": (12, 16, 400, 0.4),
    "labelLarge": (14, 20, 500, 0.1),
    "labelMedium": (12, 16, 500, 0.5),
    "labelSmall": (11, 16, 500, 0.5),
}

TYPE_OVERRIDES = {
    "displayLarge": {"md1": (57, 64, 300, 0.0), "md2": (57, 64, 300, 0.0)},
    "displayMedium": {"md1": (45, 52, 300, 0.0), "md2": (45, 52, 300, 0.0)},
    "displaySmall": {"md1": (36, 44, 300, 0.0), "md2": (36, 44, 300, 0.0)},
    "titleLarge": {"md1": (20, 28, 500, 0.0), "md2": (20, 28, 500, 0.15)},
}

CLASSIC_BUTTON_TRACKING = 1.25


def type_style(style: str, generation: str | None = None) -> tuple[float, float, int, float]:
    generation = generation or GENERATION
    return TYPE_OVERRIDES.get(style, {}).get(generation, TYPE_SCALE[style])


KDE_FONT_POINT_SIZE = 10.5
KDE_SMALL_FONT_POINT_SIZE = 9.0


MOTION_DURATION = {
    "short1": 50,
    "short2": 100,
    "short3": 150,
    "short4": 200,
    "medium1": 250,
    "medium2": 300,
    "medium3": 350,
    "medium4": 400,
    "long1": 450,
    "long2": 500,
    "long3": 550,
    "long4": 600,
    "extraLong1": 700,
    "extraLong2": 800,
}

MOTION_EASING = {
    "standard": (0.2, 0.0, 0.0, 1.0),
    "standardAccelerate": (0.3, 0.0, 1.0, 1.0),
    "standardDecelerate": (0.0, 0.0, 0.0, 1.0),
    "emphasized": (0.2, 0.0, 0.0, 1.0),
    "emphasizedAccelerate": (0.3, 0.0, 0.8, 0.15),
    "emphasizedDecelerate": (0.05, 0.7, 0.1, 1.0),
    "legacy": (0.4, 0.0, 0.2, 1.0),
}

CLASSIC_EASING = {
    "standard": (0.4, 0.0, 0.2, 1.0),
    "standardAccelerate": (0.4, 0.0, 1.0, 1.0),
    "standardDecelerate": (0.0, 0.0, 0.2, 1.0),
    "emphasized": (0.4, 0.0, 0.2, 1.0),
    "emphasizedAccelerate": (0.4, 0.0, 1.0, 1.0),
    "emphasizedDecelerate": (0.0, 0.0, 0.2, 1.0),
    "legacy": (0.4, 0.0, 0.2, 1.0),
}

SPRING = {
    "spatialDefault": (0.9, 0.7),
    "spatialFast": (0.9, 0.35),
}


STATE = {
    "hover": 0.08,
    "focus": 0.10,
    "pressed": 0.10,
    "dragged": 0.16,
    "disabledContent": 0.38,
    "disabledContainer": 0.12,
}


SPACING = {
    "xs": 4,
    "s": 8,
    "m": 12,
    "l": 16,
    "xl": 24,
    "xxl": 32,
}


def rgb(role: str, dark: bool = True) -> tuple[int, int, int]:
    table = DARK if dark else LIGHT
    return m3color.rgb_from_hex(table[role])


def kde_rgb(role: str, dark: bool = True) -> str:
    r, g, b = rgb(role, dark)
    return f"{r},{g},{b}"


def mix(first: str, second: str, amount: float, dark: bool = True) -> str:
    a = rgb(first, dark)
    b = rgb(second, dark)
    return m3color.hex_from_rgb(
        tuple(round(a[i] + (b[i] - a[i]) * amount) for i in range(3))
    )
