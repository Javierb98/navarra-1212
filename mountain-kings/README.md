# Espadas de Hispania

*Battles of medieval Spain, 722–1212 · Batallas de la España medieval, 722–1212*

A browser turn-based tactics game about three battles in the mountains of
northern Iberia, 722–939, inspired by the mechanics of the 2009 Flash game
*1066*. All art, emblems, text and taunts are original.

**Status:** the campaign's four battles are playable (Covadonga 722, Roncesvalles 778, Simancas 939, and the epilogue Las Navas de Tolosa 1212), plus custom battles (any people against any, on any field) and a page crediting 1066, the game this one is modelled on. Figures are drawn in code; final art is a later pass.

## Run it

No build step and no dependencies. It needs any static server, because the
browser won't load ES modules or JSON from `file://`:

```sh
npm start            # python3 tools/serve.py 8000 (no-cache dev server)
# open http://localhost:8000
```

Add `?debug` to the URL to expose the live battle as `window.__battle`.

## Test it

```sh
npm test             # node --test, Node 20+
```

`tests/balance.test.js` plays each battle 16 times with an AI in charge of the
player's side, and 16 times with a player who never gives an order. The first
must win at least 60% (and not 100%); the second must never win. It currently
covers all four campaign battles; the engine tests also play every custom-battle pairing on every field. **If you change a number in `data/`, run it.**

`node tools/trace.js <seed> [ai|still]` prints one battle turn by turn as ASCII,
which is the fastest way to see *why* a balance number moved.

## Layout

| Path | What |
| --- | --- |
| `src/core/` | Engine: `battle.js` (rules, turn resolution), `ai.js`, `army.js` (point-buy, deployment), `grid.js`, `rng.js`. **No DOM.** Deterministic from a seed. |
| `src/ui/` | Screens, event playback, i18n. `scene.js` draws the side-on silhouette battlefield (the 1066 top view), `board.js` the dark tactical grid below it, `iberia.js` the watercolour map cutscene. Both battle views read the same animated display units. |
| `data/rules.json` | Every combat constant, and the terrain table. |
| `data/units.json` | Factions (traits, colour, emblem) and unit stats/costs. |
| `data/taunts.json` | 48 taunts, EN/ES, flavoured by speaker's faction. |
| `data/battles/*.json` | Scenario: map, deploy zones, enemy army, objective, historical notes, sources. |
| `data/strings.json` | All UI text, EN/ES. |

Rules to keep:

1. `src/core/` never touches the DOM, timers or `Math.random`. All randomness
   goes through `battle.rng`.
2. Adding a battle should mean adding a JSON file (and a map), not code.
3. Historical notes say what the sources say. `legendNote` is for where legend
   and record part ways.

## How a turn works

Both sides give orders, then `Battle.resolveTurn()` carries them out one
company at a time, alternating sides (ours, theirs, ours…), each side in the
order its orders were given; who goes first alternates every turn. A selected
group (shift-click) is ordered as a formation and acts in a single slot,
moving in lockstep. Then routing companies run, morale is checked, and the
objectives scored. It returns events, which the UI animates; the engine never
waits on the UI.

See `PLAN.md` for what comes next.
