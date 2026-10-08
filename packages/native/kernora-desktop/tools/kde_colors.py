
from __future__ import annotations

import kernora_design as design


def colour_set(
    roles: dict[str, str],
    background: str,
    alternate: str,
    foreground: str,
    dark: bool,
) -> dict[str, str]:
    return {
        "BackgroundNormal": kde(roles, background),
        "BackgroundAlternate": kde(roles, alternate),
        "ForegroundNormal": kde(roles, foreground),
        "ForegroundInactive": kde(roles, "onSurfaceVariant"),
        "ForegroundActive": kde(roles, "primary"),
        "ForegroundLink": kde(roles, "primary"),
        "ForegroundVisited": kde(roles, "tertiary"),
        "ForegroundNegative": kde(roles, "negative"),
        "ForegroundNeutral": kde(roles, "neutralYellow"),
        "ForegroundPositive": kde(roles, "positive"),
        "DecorationFocus": kde(roles, "primary"),
        "DecorationHover": kde(roles, "primary"),
    }


def kde(roles: dict[str, str], role: str) -> str:
    import m3color

    r, g, b = m3color.rgb_from_hex(roles[role])
    return f"{r},{g},{b}"


APP_SELECTION = ("primaryContainer", "secondaryContainer", "onPrimaryContainer")
ACCENT_SELECTION = ("primary", "primaryContainer", "onPrimary")


def render(
    dark: bool,
    surfaces: dict[str, tuple[str, str]] | None = None,
    name: str | None = None,
    selection: tuple[str, str, str] = APP_SELECTION,
) -> str:
    roles = design.DARK if dark else design.LIGHT
    label = design.GENERATION_LABEL[design.GENERATION]
    name = name or f"{design.SCHEME_NAME}{design.COLOUR_LABEL}{label} {'Dark' if dark else 'Light'}"
    surfaces = surfaces or {}

    def pick(section: str, background: str, alternate: str) -> tuple[str, str]:
        return surfaces.get(section, (background, alternate))

    sections: list[tuple[str, dict[str, str]]] = []

    sections.append(
        (
            "ColorEffects:Disabled",
            {
                "Color": kde(roles, "surfaceContainerHighest"),
                "ColorAmount": "0",
                "ColorEffect": "0",
                "ContrastAmount": "0.62",
                "ContrastEffect": "1",
                "IntensityAmount": "0",
                "IntensityEffect": "0",
            },
        )
    )
    sections.append(
        (
            "ColorEffects:Inactive",
            {
                "ChangeSelectionColor": "true",
                "Color": kde(roles, "outline"),
                "ColorAmount": "0.025",
                "ColorEffect": "2",
                "ContrastAmount": "0.1",
                "ContrastEffect": "2",
                "Enable": "false",
                "IntensityAmount": "0",
                "IntensityEffect": "0",
            },
        )
    )

    sections.append(
        (
            "Colors:Button",
            colour_set(roles, *pick('Colors:Button', "surfaceContainerHigh", "surfaceContainerHighest"), "onSurface", dark),
        )
    )
    sections.append(
        (
            "Colors:Complementary",
            colour_set(roles, *pick('Colors:Complementary', "surfaceContainer", "surfaceContainerHigh"), "onSurface", dark),
        )
    )
    sections.append(
        (
            "Colors:Header",
            colour_set(roles, *pick('Colors:Header', "surfaceContainer", "surfaceContainerHigh"), "onSurface", dark),
        )
    )
    sections.append(
        (
            "Colors:Header][Inactive",
            colour_set(roles, *pick('Colors:Header][Inactive', "surfaceContainerLow", "surfaceContainer"), "onSurfaceVariant", dark),
        )
    )
    selection_background, selection_alternate, selection_ink = selection
    selected = colour_set(roles, selection_background, selection_alternate, selection_ink, dark)
    for key in ("ForegroundInactive", "ForegroundActive", "ForegroundLink", "ForegroundVisited"):
        selected[key] = kde(roles, selection_ink)
    sections.append(("Colors:Selection", selected))

    tooltip_ink = "onSurface" if "Colors:Tooltip" in surfaces else "inverseOnSurface"
    tooltip = colour_set(roles, *pick('Colors:Tooltip', "inverseSurface", "inverseSurface"), tooltip_ink, dark)
    tooltip["ForegroundInactive"] = kde(roles, "onSurfaceVariant" if tooltip_ink == "onSurface" else tooltip_ink)
    sections.append(("Colors:Tooltip", tooltip))

    sections.append(
        (
            "Colors:View",
            colour_set(roles, *pick('Colors:View', "surfaceContainerLowest", "surfaceContainerLow"), "onSurface", dark),
        )
    )
    sections.append(
        ("Colors:Window", colour_set(roles, *pick('Colors:Window', "surface", "surfaceContainerLow"), "onSurface", dark))
    )

    sections.append(
        (
            "General",
            {
                "ColorScheme": design.scheme_id(dark),
                "Name": name,
                "shadeSortColumn": "true",
                "accentColorFromWallpaper": "false",
            },
        )
    )
    sections.append(("KDE", {"contrast": "4"}))
    sections.append(
        (
            "WM",
            {
                "activeBackground": kde(roles, "surfaceContainer"),
                "activeBlend": kde(roles, "surfaceContainer"),
                "activeForeground": kde(roles, "onSurface"),
                "inactiveBackground": kde(roles, "surface"),
                "inactiveBlend": kde(roles, "surface"),
                "inactiveForeground": kde(roles, "onSurfaceVariant"),
            },
        )
    )

    lines = [
        f"# {name}: generated from the Kernora Material 3 palette.",
        f"# Seed colour {design.SEED}. Do not edit; run tools/gen-color-schemes.",
        "",
    ]
    for section, entries in sections:
        lines.append(f"[{section}]")
        for key in sorted(entries):
            lines.append(f"{key}={entries[key]}")
        lines.append("")
    return "\n".join(lines)
