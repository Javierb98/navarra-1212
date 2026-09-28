# 1212 — Las Cadenas de Navarra

A short historical battle game for a home-built arcade cabinet running on a
Raspberry Pi. Seven battles from the Kingdom of Navarre, from the ambush at
Roncesvalles in 778 to Las Navas de Tolosa in 1212, played with the
simultaneous-orders, morale-driven combat of the Flash game *1066*.

Built in **Godot 4** (GL Compatibility renderer). Game text is **Spanish**;
code and comments are English. An `en` column already exists in the string
table — see [Language](#language).

## Running it

```sh
# Open in the editor
/Applications/Godot.app/Contents/MacOS/Godot --path .

# Or run it directly
/Applications/Godot.app/Contents/MacOS/Godot --path . --fullscreen
```

Keyboard controls on a dev machine (the cabinet mapping is in
`src/autoload/arcade_input.gd`):

| Action | Keys |
| --- | --- |
| Move / change order | arrows or WASD |
| Confirm | Enter or Z |
| Back | Esc or X |
| Commit the round | Space |
| Commander's ability | E |
| Start / coin | 1 / 5 |

## Tests

Both suites are headless and take a couple of seconds.

```sh
GODOT=/Applications/Godot.app/Contents/MacOS/Godot

# Combat engine, plus a balance sweep over all seven battles
$GODOT --headless --path . --script tests/test_battle.gd

# Every screen builds without errors
$GODOT --headless --path . --script tests/test_screens.gd
```

The balance sweep is the useful one. It plays every scenario eight times with a
reference "sensible player" and eight times with a player who just holds
everything still, then asserts each battle is winnable by the first and not by
the second. It prints the win rates, which are the numbers to look at when
tuning a scenario:

```
ok   atapuerca_1054: se puede ganar (3/8 jugando bien, 0/8 quieto)
ok   navas_de_tolosa_1212: se puede ganar (7/8 jugando bien, 0/8 quieto)
```

If you change a combat constant, run this before anything else.

> One deliberate oddity: Valdejunquera scores badly for the "sensible" player
> and well for the passive one. It is a survival scenario modelling a defeat,
> and holding is genuinely the right answer there.

## Layout

```
data/battles/*.json   the seven battles — history lives here, no code needed
src/core/             combat engine; no scene tree, fully headless, unit-tested
src/ui/               screens, built in code (see docs/DISENO.md for why)
src/autoload/         config, translations, arcade input, progress, attract mode
shaders/              parchment ground
assets/heraldry/      faction shields as SVG
i18n/strings.csv      all UI text, one row per key
tools/                Raspberry Pi export and kiosk setup
docs/                 design, history and sourcing, art direction, deployment
```

## Documentation

- [`docs/DISENO.md`](docs/DISENO.md) — how the game works, every tuning knob,
  and the scenario JSON schema.
- [`docs/HISTORIA.md`](docs/HISTORIA.md) — the seven battles, sources, and an
  explicit list of what is recorded versus what is legend or invented.
- [`docs/ARTE.md`](docs/ARTE.md) — the art plan, written for someone who does
  not draw. Public-domain manuscript sources and how to unify them.
- [`docs/DESPLIEGUE-PI.md`](docs/DESPLIEGUE-PI.md) — exporting to the Pi and
  setting up the cabinet as a kiosk.

## Language

UI strings are in `i18n/strings.csv`, which has `es` and `en` columns and is
parsed at boot by `src/autoload/loc.gd` — no import step, edits show up on the
next run. Battle prose (briefings, historical notes) is currently Spanish-only
and lives in the scenario JSON; localising it means a parallel set of data
files. `Cfg.locale` selects the language.

## State

Playable end to end: attract → campaign → briefing → battle → aftermath, with
all seven battles implemented and balanced. What it does not have yet is
animation, sound, and figurative art — see `docs/ARTE.md` for the plan and
`docs/DISENO.md` for the open design questions.
