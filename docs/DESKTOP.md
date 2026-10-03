# Desktop: the Kernora Material 3 shell

`packages/native/kernora-desktop` turns Plasma into the Kernora desktop: a
complete Material 3 design, generated from one seed colour, and three pieces of
shell built on it — a minimal floating panel, an application launcher and a
quick settings shade pulled up from the panel.

Plasma, KWin and the Qt applications stay unmodified Debian packages. Kernora
only adds themes, applets and defaults, so every upstream update keeps working.

## One seed, every asset

```text
tools/kernora_design.py    seed #ff6a1e, shape, type, motion, state tokens
        |
tools/m3color.py           HCT / CAM16 -> Material 3 tonal palettes and roles
        |
        +-- gen-color-schemes   KernoraDark.colors, KernoraLight.colors
        +-- gen-kdeglobals      /etc/xdg/kdeglobals: scheme, Roboto, icon theme
        +-- gen-plasma-theme    Plasma desktop theme "kernora" (SVG + colors)
        +-- gen-icon-theme      icon theme "Kernora" from Material Symbols
        +-- gen-qml-tokens      M3.qml, the singleton the shell's QML reads
        +-- gen-wallpaper-assets  Material shapes and colour tracks of the live wallpaper
        +-- gen-kvantum-theme   Kvantum theme "Kernora" for every Qt widget
        +-- gen-aurorae-theme   window decoration "kernora"
        +-- gen-translations    .po -> .mo
```

All generators run inside the offline package build (`debian/rules`); nothing
generated is kept in Git. Changing `SEED` in `kernora_design.py` recolours the
colour schemes, the Plasma theme, the icons' fallback ink and the shell at once.

`m3color.py` implements HCT the way Google's Material Color Utilities do
(CIECAM16 hue and chroma, CIE L\* tone). It reproduces the published baseline
palette of `#6750A4` tone for tone. The scheme uses the "vibrant" hue rotations
for secondary and tertiary; the neutral family keeps only a trace of the seed
(chroma 4/8) so large surfaces stay calm over Kernora's cool wallpaper.

QML note: a property named `on<Uppercase>` is a signal handler in QML, so the
Material "on" roles are spelled as content roles in `M3.qml` — `onPrimary` is
`M3.primaryContent`, `onSurfaceVariant` is `M3.surfaceVariantContent`. The
source test rejects `M3.on*`.

## Styles: Material Design 1, 2 and 3

Kernora wears any of the three generations of Material, drawn from the same
seed and the same typeface, so they read as Kernora in three eras rather
than three systems. Settings (Wallpaper & style → Style) and Welcome switch
them at run time, for the whole session at once.

| | Material Design 1 (2014) | Material Design 2 (2018) | Material 3 (2021) |
|---|---|---|---|
| Surfaces | grey 50 / grey 850 paper on shadows | white / #121212 with overlays | tonal, tinted by the seed |
| Colour | ember primary, violet accent | ember primary, violet accent | tonal palettes of the seed |
| Corners | 2dp | 4dp small, 8dp cards, 16dp sheets | 28dp dialogs, pills |
| Buttons | 36dp, capitals, raised | 36dp, capitals, raised | 40dp pills |
| Switches, sliders | thin track, round thumb | thin track, round thumb | Material 3 |
| Quick settings | bare icons over labels, four columns | round toggles, four columns | wide tiles, two columns |
| Panel | a shelf on the screen edge | floating, 8dp | a floating pill |

`tools/kernora_design.py` defines the three generations: their palettes
(Material 1 and 2 expressed in Material 3's roles, so every component keeps
working), corner radii per kind of component (`CORNERS`), shadows
(`ELEVATION`, `ELEVATION_LEVEL`), component behaviour (`COMPONENT`), type
differences and easing curves.

* **QML.** `gen-qml-tokens` puts all three into `M3.qml`. The singleton reads
  `generation` from `~/.config/kernorarc` (`[Style] generation=md1|md2|md3`)
  whenever the colour scheme or Plasma theme changes. Each generation has its
  own scheme, so a switch always comes with such a change and every surface
  reskins live. Components read `M3.classic`, `M3.radius(kind, height)`,
  `M3.corner<Kind>`, `M3.elevationOf(kind)`, `M3.buttonUppercase`,
  `M3.tileStyle` and `M3.slabGap`. Material 3 keeps its own expressive
  details: shape morphs on press, the thick slider, the switch with a
  checkmark.
* **Generated themes.** The colour schemes, the Plasma theme, Kvantum and
  the window frames are written once per generation, with
  `KERNORA_GENERATION` naming it. Material 3 keeps the names Kernora always
  used (`KernoraDark`, `kernora`, `Kernora`). The older generations add
  theirs: `KernoraMD2Dark`, `kernora-md2`, `KernoraMD2`, `kernora-md2-light`.
* **Switching.** `org.kernora.system`'s `Appearance.apply(generation, dark)`
  (kernora-apps) does the work:
  * it writes kernorarc;
  * it points Kvantum at the generation's theme and passes through the other
    widget style, so running applications load the new theme;
  * it sets the window frames;
  * it floats the panel, or not for Material Design 1;
  * it applies the Plasma theme, then the colour scheme.

The login screen (SDDM) runs before anyone logs in and keeps Material 3; the
lock screen follows the user's style. So does the boot (GRUB, Plymouth).

## Icons

`data/symbols/` vendors Material Symbols Rounded, weight 400, optical size 24
(Apache-2.0), pinned by SHA-256 in `data/symbols.lock`. `tools/symbols_map.py`
maps each drawing to the freedesktop names the shell and the system ask for;
`tools/fetch-symbols` refreshes the vendored files (development only, the build
has no network) and `fetch-symbols --check` verifies them during the build.

* Every drawing is re-gridded onto 24×24 and wrapped in the Breeze
  colour-scheme stylesheet, so Plasma recolours it with the palette.
* Aliases, including every `-symbolic` spelling, are symlinks.
* Application icons are left alone: apps keep their own full-colour icons in
  the launcher and the taskbar. Kernora's own applications are the exception:
  `APP_ICONS` draws a themed icon for them — the filled symbol on a round
  tonal container, full colour, as a Pixel themes its app icons. System
  Settings (`preferences-system`, `systemsettings`) is drawn that way.
* Every System Settings module and category has its own symbol. An unmapped
  `preferences-desktop-foo` would fall back to `preferences-desktop` and every
  module would wear the same glyph.
* `fetch-symbols` refuses drawings on the legacy 24-unit grid that some names
  still serve upstream; the theme is drawn on the 960-unit Symbols grid only.
* The Plasma theme also carries `icons/<prefix>.svg` sheets drawn from the same
  symbols, because Plasma looks there before the icon theme.
* Names not mapped fall back to Breeze (`Inherits=breeze-dark,breeze,hicolor`).

## Plasma theme

`gen-plasma-theme` draws the nine-slice SVGs Plasma frames its surfaces with:

| File | Material role |
| --- | --- |
| `widgets/panel-background` | floating pill, radius = half the 56px thickness |
| `dialogs/background` | popups: extra-large 28dp corners, level-3 shadow |
| `widgets/tooltip` | rich tooltip on the highest container |
| `widgets/tasks` | task buttons as tonal containers, primary tint when active |
| `widgets/slider`, `lineedit`, `button` | 16dp track, pill fields and buttons |
| `widgets/listitem`, `viewitem`, `scrollbar`, `tabbar`, `line` | state layers, thin thumbs |

Every piece is painted with a KDE colour-scheme class, so the theme's `colors`
file (also generated) decides the tones. Plasma surfaces sit on
`surfaceContainer`; tooltips and buttons one level up. Anything the theme does
not ship falls back to Breeze.

## Shell

The applets live in `data/shell/`. Both copy the shared component library
`data/shell/m3/` into their own package at build time, with a freshly generated
`M3.qml`, so neither depends on a QML import path.

### Components (`data/shell/m3`)

`MText` (type scale), `MIcon` (tinted symbol at an exact size), `MStateLayer`
(hover/focus state layer and a ripple clipped to the container), `MIconButton`,
`MButton`, `MSwitch`, `MSlider`, `MTile`, `MSearchBar`, `MMenu`,
`MScrollIndicator` and `MSpring`, a damped spring integrated per frame so
released surfaces keep the velocity the pointer gave them.

`MSlider` is the Material 3 expressive slider: a 40dp track split by a slim
handle with 6dp gaps, small inner corners, the icon inside the track (it moves
to the inactive side when the active part is too short), a stop indicator, and
a value bubble while held. It shows its own value until the backend catches up,
so a slow audio or backlight service never makes the handle jump back.

### Panel (`look-and-feel/.../org.kde.plasma.desktop-layout.js`)

One floating, full-width panel: launcher, centred tasks, the system tray, the
notifications bell and the quick settings chip, plus the clipboard applet,
which takes no room. The tray is limited to
application status icons (all Plasma tray applets are marked known and none is
enabled), because the shade covers them and a passive tray applet would sit
behind an expander arrow. Notifications stay a separate applet: it also hosts
the notification popups.

New accounts do not autostart the Xwayland video bridge (see
`data/skel-autostart/`): its status icon is permanently passive and would bring
the arrow back. Kernora's applications are native Wayland clients.

### Launcher (`org.kernora.launcher`)

A popup built on Plasma's Kicker models, so it lists exactly what Plasma knows:

* a search bar that takes focus on open; typing anywhere searches through
  KRunner (applications, settings modules, calculator, …); the best match is
  pre-selected so Enter launches it;
* the pinned shelf — Plasma's shared favourites; right-click or press and hold
  a tile to pin or unpin it;
* all applications in one alphabetical grid with a staggered entrance;
* the account, System Settings, lock, log out and shut down.

It provides `org.kde.plasma.launchermenu`, so Meta opens it; Alt+F1 as well.
The popup grows with the application list and scrolls past 680px.

### Quick settings (`org.kernora.quicksettings`)

The status chip in the panel (network, volume, battery, clock) is the handle of
the shade. A Plasma popup opens and closes as a unit, so the shade is its own
transparent full-screen `PlasmaCore.Dialog`; the window never moves or resizes,
only the sheet and the scrim inside it do.

* **Click** the chip, or press **Meta+A**: the shade springs open. (Plasma
  delivers the shortcut as a flip of the applet's `expanded` state; the
  applet has no popup, so each flip toggles the shade.)
* **Press and drag up** on the chip: the sheet follows the pointer 1:1; past
  fully open it resists like a rubber band. On release the velocity of the last
  100ms decides (a flick beats position) and seeds the spring.
* **Two-finger swipe** on a touchpad over the chip or the sheet drives the same
  path; a mouse wheel notch opens or closes.
* **Swipe down** on the sheet, click the chip again or anywhere outside the
  sheet, press Escape, Meta+A or any other Meta chord, or focus another
  window: it closes.

The sheet rises from below the screen edge and comes to rest 8px above the
panel, lined up with the chip, which stays visible in its active tint. When
the screen is too short for all of it, the sheet stops at the screen's top
gap and its content scrolls; a swipe on the handle strip still closes it.

The sheet holds the clock and date, a battery chip on machines with a battery,
System Settings and a power menu (lock, sleep, log out, restart, shut down),
the brightness and volume sliders, and ten tiles: Wi-Fi, Bluetooth, Sound,
Microphone, Do Not Disturb, Night Light, Airplane Mode, Keep Awake, Dark Theme
and Screenshot. Tiles with more settings show a chevron; it (or a right-click)
opens the matching System Settings page. Dark Theme switches the whole system
through `org.kernora.system`'s Appearance (kernora-apps), as Settings does;
without kernora-apps the tile is unavailable. Screenshot closes the shade and
then starts the Screenshot app, which captures the screen as it starts.

While something plays, Android's media card closes the sheet: the artwork
behind a scrim, the app and the track, a play button that squares off while
playing, and a seek bar that flows as a wave (`WavyProgress.qml`). Any MPRIS
player drives it; Kernora's Media Player speaks MPRIS through
`org.kernora.system`'s `MprisPlayer`.

The applet also announces removable storage: a USB drive or memory card
plugged in brings a notification from Files with "Open", which mounts it and
opens it there (`sources/DeviceSource.qml`, on the model of Plasma's device
notifier; `data/knotifications/kernora-devices.notifyrc` makes it come from
Files).

Data comes from Plasma's own integrations (NetworkManager, BlueZ, PipeWire,
PowerDevil, KWin Night Light, the notification server, MPRIS). Each lives in
its own file under `shade/contents/ui/sources/` behind a `Loader`: a missing
service disables its tiles instead of breaking the shade.

### Clipboard and emoji (`org.kernora.clipboard`)

**Meta+V** opens the clipboard history as a sheet centred above the panel:
Clipboard and Emoji tabs, a search bar that takes the keyboard, and the
copied items as one
slab of cards, the newest (what is on the clipboard now) on top. Text shows
three lines; a web address gets the link symbol with its site as the
headline; a picture shows as a thumbnail with its size; copied files show
the first one's preview and name. The current card offers "Remove", and
"Clear all" empties the history. Enter or a click copies the item again
(it moves to the top) and closes the sheet; Escape, a click elsewhere or
any Meta chord closes it.

**Meta+.** opens the same sheet on its Emoji tab, laid out like a phone
keyboard's: category tabs (recently used first), the emoji in rows under
their group's name, the name of the one under the pointer, and search by
name and keyword in English and Russian. A click copies the emoji (it also
lands in the clipboard history) and closes the sheet. The panel holds two
instances of the applet, one per shortcut (`startPage` in its
configuration); the recently used emoji are shared in
`~/.config/kernora-emojirc`. Plasma's emoji selector keeps only its other
shortcut (its kglobalaccel file is diverted). `emoji.js` is generated by
`tools/gen-emoji-data` from Debian's unicode-data and unicode-cldr-core and
kept in the tree; sequences are drawn without U+FE0F, which keeps Qt 6.8
from joining them, and copied fully qualified.

The history is Plasma's Klipper, which lives in the QML plugin of Plasma's
clipboard applet (`org.kde.plasma.private.clipboard`) and records from the
moment something loads it. Its own popup is compiled into that plugin and
cannot be restyled, so this applet loads the model itself, stays hidden in
the panel outside edit mode, and draws the sheet in its own
`PlasmaCore.Dialog`. Klipper's "show at mouse position" action would take
Meta+V first: new accounts get it without a shortcut
(`data/skel-config/kglobalshortcutsrc`). `/etc/xdg/klipperrc` keeps
pictures in the history.

## System surfaces

Plasma loads some surfaces from places a look-and-feel package cannot
reach. `kernora-desktop` puts Kernora's in place with `dpkg-divert`
(`debian/kernora-desktop.preinst`), and every diverted file is listed in
the package and live-image tests.

* **Lock screen** (`data/lockscreen`, over the shell package's
  `lockscreen/LockScreen.qml`): Kernora Shapes behind a large clock, the
  account card, power actions, and the playing media's controls at the
  bottom, usable without unlocking.
* **On-screen display** (`data/osd`, over `osd/Osd.qml`): volume and
  brightness as a thick slider, messages as a pill.
* **Notifications** (`data/notifications`): Plasma's notification applet is
  a C++ plugin, so only its QML entry point (`main.qml`) is diverted. It
  loads Kernora's popups, history and panel bell from `contents/ui/kernora/`
  and never imports the stock files next to it, whose popup manager would
  open a second set of popups. Popups follow Android's layout (app badge,
  "App · time", title, text, picture, tonal actions, file-job progress). The
  history is one slab of cards with Do not disturb and "Clear all". The
  bell badges unread notifications and rings with the jobs' progress.
* **Settings window** (`data/configuration`, over the shell package's
  `AppletConfiguration.qml`, `ConfigurationContainmentAppearance.qml`,
  `ConfigurationContainmentActions.qml`, `ConfigurationShortcuts.qml` and
  `AboutPlugin.qml`): the window
  that right-click → Desktop and Wallpaper, or an applet's Configure, opens.
  Sections are a navigation list as in Kernora Settings; the page sits on a
  rounded pane under its headline, with Material buttons at the foot. The
  folder view's Location, Icons and Filter pages (`data/folderview`, over
  `org.kde.desktopcontainment/contents/ui/Config*.qml`) keep their `cfg_*`
  properties and the folder view's translations; titles that Plasma writes
  as form labels lose their colon.
* **Power menu** (`look-and-feel/.../logout`) and **Alt+Tab**
  (`data/kwin-tabbox/org.kernora.switcher`, a KWin window switcher).
* **Task manager** (`data/taskmanager`): count badges as Material badges;
  tooltip previews and album art on rounded tiles (`Badge.qml`,
  `ToolTipInstance.qml`).
* **Alt+Space** opens the Kernora launcher. KRunner's kglobalaccel service
  file is diverted so that its own window keeps Alt+F2.
* **Authentication prompt**: `packages/derived/polkit-kde-agent-1` rebuilds
  Debian's agent with a Material 3 dialog. It is a frameless card that uses
  only Kirigami and the colour scheme, so the agent depends on no Kernora
  QML.
* **Boot**: `tools/gen-plymouth-theme` writes the Plymouth theme: the mark
  and Material's loading indicator, its expressive shapes turning into one
  another, plus a passphrase pill. `tools/gen-grub-theme` writes the boot
  menu: the mark over rounded cards, no countdown, fonts made from Roboto by
  `grub-mkfont`. Plymouth's defaults are diverted.
  `/etc/default/grub.d/kernora.cfg` adds `splash` and the theme for an
  installed system; the ISO build copies the theme onto the medium.

## Live wallpaper (`org.kernora.shapes`)

Kernora Shapes takes the character of the Pixel welcome animation: Material 3
Expressive shapes — nine- and six-lobed cookies, a flower, suns, clovers, a
pill — turning slowly, travelling on rounded orbits and passing over one
another, while their colours shift between moods.

* `tools/material_shapes.py` ports AndroidX `RoundedPolygon` and the
  `MaterialShapes` catalogue (rounding and smoothing included);
  `gen-wallpaper-assets` writes the outlines as SVG paths and, per colour slot
  and tone, a colour track over the loop, cross-faded in HCT so no transition
  passes through grey.
* `choreography.js` places everything as a function of one phase: orbits are
  sums of circles with whole-number frequencies, rotations whole turns, colour
  moods evenly spaced — every curve ends where it began, so the three-minute
  loop has no seam. The drawing order is precomputed per sample: when two
  shapes meet one passes over the other, and the next time they meet the
  other does; the order only changes between shapes that do not touch.
* The scene advances 30 times a second (its fastest shape moves well under a
  pixel per step), pauses while a maximised or full-screen window hides the
  desktop, and holds still when animations are off. Speed, colour cycling and
  pausing are in the wallpaper's settings.

### More live wallpapers

Kernora ships only live wallpapers; Shapes is the default. The others are
Material shapes at play, in the same flat Material 3 tones -- toys, not
landscapes. Each is a Plasma wallpaper package in `data/wallpaper/` with the
same parts: a pure `Scene.qml` driven by `phase` (0..1) and `intro`, the
`main.qml` that runs the clock and pauses behind windows, and `config.qml`
for speed and pausing. `gen-wallpaper-assets OUT THEME` writes each package's
`materialshapes.js` -- the shapes Shapes uses, each with its outline and its
convex hull -- and `palette.js`, a tonal palette of HCT families for the
scene; the palette's `c(family, tone)` returns the nearest tone it has.
Settings and Welcome load `Scene.qml` directly for previews
(`Files.liveWallpapers()`), a still at phase 0.3.

* **Tower** (`org.kernora.tower`, 50 s): a stack of toy blocks on warm
  paper -- a slab, a square, a cookie, an arch, a ball, a clover, a sun --
  rocks on the edge of its base, once, twice, a third time too far, and
  goes over; the pieces fly, bounce, rock and roll until each lies on a
  flat side, then hop home one by one, from the base up, landing with a
  squash. `tower.js` simulates the fall once per screen size: the standing
  tower is a rigid body tipping about its edge; a loose piece flies under
  gravity and on the floor rocks and rolls on its hull about its centre of
  mass, so a square settles on a side and an arch onto its foot; pieces on
  the floor overlap a little, as a heap does, and no more. The run is
  sampled into a table the scene looks poses up in; about 90 ms per size.
* **Rhythm** (`org.kernora.rhythm`, 160 s): a pendulum wave in the round.
  24 shapes on rays from the centre swing in and out, each one beat a loop
  faster than the one before; they start as a circle, wind into a spiral,
  split into two arms, three, a star, and close into the circle again at
  the end of the loop. Behind them, a blob whose outline is a Catmull-Rom
  curve through the shapes morphs with the pattern; a slower inner ring
  keeps its own time round an ember sun.
* **Marble Run** (`org.kernora.marbles`, 60 s): five shape marbles roll
  down a zigzag of wooden ramps on a green board, fly off each end onto the
  ramp below, knock against its post -- whose little sun nods -- and roll
  back the other way, until the last ramp runs them into the lift, whose
  cups carry them back to the top. `run.js` simulates one marble's trip
  (rolling on a slope, flight, landing hops, posts); the others follow at
  even intervals, and the lift's speed makes a trip a whole fraction of
  the loop. In its cup a marble turns back to its starting angle, modulo
  its symmetry, so every trip starts alike.

Picture wallpapers are not installed. kernora-desktop no longer ships one,
and Breeze's (`breeze-wallpaper`, a dependency of `breeze`) is removed from
the image by `build-live-rootfs` and kept out on upgrades by `path-exclude`
in `/etc/dpkg/dpkg.cfg.d/kernora-wallpapers`. Pictures of one's own still
work.

## Cursors (`kernora_cursors`)

`tools/gen-cursor-theme` draws every cursor as SVG on Breeze's 32-unit canvas
for a nominal 24 px cursor: a warm near-black glyph (neutral tone 10 of the
seed) with a white outline and a soft shadow, and rounded ends and corners.
Badges (copy, link, help, menu) are ember. `wait` and `progress` animate
Material 3 Expressive's loading indicator: softBurst, cookie9, pill, sunny
and cookie4, each morphing into the next while it turns. The shapes come
from `material_shapes.py`, morphed through their radii about the centre
(every Material shape is star-shaped). The indicator sits inside a light
ember container.

* `cursors/` holds Xcursor files at nominal sizes 24 to 72, assembled by the
  tool from `rsvg-convert` output. `cursors_scalable/` holds the SVGs with
  KWin's `metadata.json`. The legacy X names, the hashes and the CSS names
  are links, following Breeze's table, and Breeze is inherited for anything
  else.
* The look-and-feel, `/etc/xdg/kcminputrc` and SDDM select it, and the
  package registers it as `x-cursor-theme` with priority 100 (Adwaita's is
  90).
* Launch feedback: `/etc/xdg/klaunchrc` turns off KWin's bouncing and blinking
  icon. While a program starts, the pointer becomes the animated `progress`
  cursor.

The host has no `rsvg-convert`, so `scripts/preview-desktop sync` makes the
theme in the package build chroot, unpacked under `/tmp/kernora-desktop-dev`.

## Applications

The same tokens reach applications through three stock mechanisms, so no KDE
package is patched:

* **Widgets** — `gen-kvantum-theme` writes the Kvantum theme `Kernora`
  (`kvantum-dark` is the default widget style; `kvantum` is its light
  variant). Menus and submenus: 12px rounded container on
  `surfaceContainerHigh`, hairline, soft shadow, 36px rows with an inset tonal
  pill on hover. Buttons are tonal pills that flatten towards a rounded square
  while pressed; fields are filled with 10px corners and a primary focus ring;
  check boxes, radio buttons, the 14px slider with its bar handle, pill tabs,
  thin transient scroll bars and lists follow Material geometry. Every slice
  is drawn at the size Kvantum paints it, so rings stay exact.
* **Qt Quick** — `data/style/org.kernora.desktop` is a Qt Quick Controls style
  selected for the session by `/etc/xdg/plasma-workspace/env/kernora-qtquick-style.sh`.
  It restyles buttons, tool buttons, switches, menus, list rows, combo box
  lists, tooltips, popups, dialogs and the busy indicator with the shell's own
  `m3` components (state layers with ripples, the spring switch) and falls
  back to KDE's desktop style for everything else, which Kvantum then draws.
  Controls that only change their look extend the stock control rather than
  copy it. Kirigami finds its platform plugin by style name, so the package
  links `org.kernora.desktop.so` to KDE's `org.kde.desktop.so`. The style was
  written against KDE Frameworks 6.13; the live image test pins that.
* **Window decoration** — `gen-aurorae-theme` writes the Aurorae theme
  `kernora`: a 38px title bar on the application header's surface with 12px
  top corners, circular Material Symbols buttons (the close button on the
  error container), a soft shadow, and a flat bar when maximised. Borders are
  "None"; KWin keeps an invisible resize margin.

Selections in applications use the primary container (`Colors:Selection`),
the way Material marks a selected navigation item; the Plasma theme keeps
the bright primary. The colour schemes carry no `AccentColor`: KDE would
otherwise recompute the selection as the accent blended into the background.

## Typography

The shell sets text in the Material type scale (`M3.bodyMedium`,
`M3.titleSmall`, …) in Roboto, which the image installs from Debian
(`fonts-roboto-unhinted`). The scale follows the user's font size through
`Kirigami.Units.gridUnit`. System-wide, `/etc/xdg/kdeglobals` sets Roboto
10.5pt, Material's 14dp body size, for Qt applications.

## Motion

Durations and easing curves are Material's (`M3.durationMedium2`,
`M3.easingEmphasizedDecelerate`, …) scaled by Plasma's animation speed, so
turning animations off in System Settings is honoured, springs included.

## Translations

`data/shell/po/<domain>.ru.po` hold the Russian catalogs; `gen-translations`
compiles them into the applet domains Plasma loads
(`plasma_applet_org.kernora.launcher`, `plasma_applet_org.kernora.quicksettings`).

## Previewing changes

`scripts/preview-desktop` boots the last live rootfs in QEMU with the freshly
built package laid over it — no live rootfs or ISO rebuild:

```sh
make kernora-desktop-binary
./scripts/preview-desktop start          # first run builds a 12G sparse base disk
./scripts/preview-desktop shot shot.png
./scripts/preview-desktop input drag 1350 862 1350 600 120   # pull the shade up
./scripts/preview-desktop run 'journalctl -b -o cat _COMM=plasmashell'
./scripts/preview-desktop sync            # push QML/theme edits, restart plasmashell
./scripts/preview-desktop stop
```

`sync` regenerates the shell, themes, wallpaper, Qt Quick style, Kvantum and
Aurorae themes and icons on the host, refreshes the look-and-feel defaults in
`~/.config/kdedefaults` and restarts plasmashell inside the running VM in
about twenty seconds; `sync --reset` also re-runs the panel layout script.
The preview keeps the screen from dimming between screenshots. Screen coordinates are those of the
1440×900 preview display.
