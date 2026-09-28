# CLAUDE.md

Conventions for this project. Read `docs/DISENO.md` before touching combat and
`docs/HISTORIA.md` before touching any historical text.

## What this is

A Godot 4 arcade game about seven battles of the Kingdom of Navarre, in the
style of the Flash game *1066*. Developed on macOS, deployed to a Raspberry Pi
that drives a home-built cabinet.

## Language split

- **Code, comments, commit messages: English.**
- **Everything the player reads: Spanish.**

UI strings go in `i18n/strings.csv` (columns `keys,es,en`) and are reached with
`tr("KEY")` or `Loc.f("KEY", [args])` — never hard-code display text in a
script. Battle prose lives in the scenario JSON and is Spanish-only for now.

## Architecture rules

1. **`src/core/` never touches the scene tree.** No `Node`, no autoloads, no
   `get_tree()`. That is what lets the whole combat engine run headless under
   `tests/test_battle.gd`, and it is the most valuable property this codebase
   has. Do not erode it for convenience.
2. **The engine is deterministic given a seed.** Use `battle.rng`, never
   `randi()` or `randf()` directly, anywhere in combat resolution.
3. **Screens are built in code**, from `ChronicleUI` builders, not laid out in
   `.tscn` files. The `.tscn` files are a root node and a script, nothing more.
4. **History goes in JSON, not in code.** Adding a battle should never require
   editing a `.gd` file except to add the id to `GameState.CAMPAIGN`.

## Before committing a combat change

```sh
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
$GODOT --headless --path . --script tests/test_battle.gd
$GODOT --headless --path . --script tests/test_screens.gd
```

`test_battle.gd` includes a balance sweep that plays all seven battles sixteen
times each and asserts every one is winnable playing sensibly and none is
winnable by standing still. It has already caught two unwinnable scenarios and
an engine-wide stalemate. **If you change a combat constant and do not run it,
you are guessing.**

Note that a new `class_name` is not visible to `--script` runs until an import
pass has registered it:

```sh
$GODOT --headless --path . --import
```

## Things that will bite

- Autoloads (`GameState`, `Cfg`, `Loc`, `Attract`, `ArcadeInput`) are **not**
  compile-time identifiers in a `--script` run. Fetch them with
  `root.get_node_or_null("GameState")` in tests. Scenes loaded at runtime are
  fine and can use the global names.
- Typed inference fails on values coming out of untyped arrays — write
  `var chosen: bool = o == current`, not `:=`.
- The renderer must stay `gl_compatibility`. Forward+ needs Vulkan and the Pi
  has no usable path for it.
- Companies in the same wing fight in **array order** in the scenario JSON. The
  first listed holds the front. Reordering that array changes the battle.

## Historical text

`nota_historica` states what the sources record — no dramatisation, no invented
motives. `advertencia` is only for separating legend from record, and should
stay empty when there is nothing to separate; it loses its force if every
battle has one. `fuentes` must be real citations.

If a player looked something up after playing, they should find the game was
straight with them.
