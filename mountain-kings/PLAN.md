# Plan after milestone 1

## Done (milestone 1)

- Engine: simultaneous orders; move, melee, missiles, taunts, rocks, rally.
- Terrain: road / slope / wooded slope / crag / high wood, height defence,
  downhill bonus, movement costs by faction (Vascones master slopes, Franks slow
  off-road), horse cannot climb crags or charge uphill, woods block missiles.
- Hidden units and ambush: hidden on cover at deployment, revealed on striking or
  adjacency; walking into one "bumps" it. The first strike from hiding gets
  ×1.6 and a morale shock to the target and its neighbours, once per unit.
- Shield wall (3 stacked vertically: ×1.5 defence, cannot be charged),
  cavalry wedge (tip charges ×1.3), guarded wagons.
- Morale: losses, shocks, rout, fleeing to own edge, leader aura, leader death,
  rally recovering runners; baggage loss hurts the Franks.
- Hit-and-run with re-hiding for Basque horse and skirmishers.
- Utility AI (sees only visible enemies).
- Roncesvalles with point-buy, deployment, results and sources. EN/ES.

Deferred from the brief to later milestones: the **feigned retreat** order,
and the rockfall/taunt **minigames** (both exist now as plain orders).

## Milestone 2: minigames

**Done:** the volley minigame (`src/ui/archery.js`). A side view along the
line of fire; drag back for angle and power, release; the volley hits whatever
is where it lands, including your own companies. The engine pauses for it via
`Battle.turnSteps()`, and `resolveTurn()` aims automatically with scatter.


Every minigame is optional, and **Auto** resolves it the way it resolves now,
so the engine only ever receives a number. Keep them in `src/ui/minigames/`.
The engine takes a `quality` in 0..1 on the order.

1. **Rockfall timing.** When the order resolves, a column of rocks is loaded
   at the top of a slope strip and a marker oscillates along the target's row.
   Release on the target: `quality` = closeness. Damage ×(0.6 + 0.8·quality);
   a miss with quality < 0.2 lands on the cell beside it, which *can* be a
   friendly unit. Three uses per army, as now.
2. **Taunt duel.** The 1066 idea, re-themed: you're shown three insult
   openings and three endings, and you pick a pair. Pairs have a hidden
   "fit" (the pool gets `opening`/`ending` tags with matching themes: goats,
   cooking, smells, cowardice). The enemy answers with its own. The better
   pair wins the morale swing. The data model extends `taunts.json` without
   breaking the current single lines.
3. **Rally horn.** A three-beat rhythm press. Hitting the beats raises
   `rallyRecoverChance`. Short, and never needed.
4. **Feigned retreat.** An order for `hitAndRun` units: withdraw two cells
   *toward* a chosen cell. Any enemy that ordered an attack on them follows
   the whole way, which breaks their shield wall or wedge and can pull them
   onto a slope. The AI needs a "pursue" discount so it can fall for this,
   but not every time.

## Milestone 3: the top cinematic view

A second renderer over the same events, toggled per turn or automatically for
big moments (ambush, leader death, wagon seized):

- An oblique "tabletop" camera over the map painted as terrain relief, with
  paper-cutout figures as billboards: one sprite per company, sized by
  strength. Plain Canvas 2D with a per-row scale gives the tilt; no WebGL needed.
- Events already carry everything needed (`steps`, `strike` with mods,
  `reveal`, `rout`); the cinematic view is another consumer of the same event
  list, next to `playback.js`.
- Beatus-style framing: the view sits inside an illuminated border with a
  caption strip ("The Vascones fall on the baggage") built from the chronicle
  line.

## Done: epilogue, Las Navas de Tolosa (1212)

Sancho VII's Navarrese on the right wing against the Almohad army. New: a
`seize` objective (enter the caliph's camp, or drive the caliph from the
field), palisade and camp terrain, `anchored` units that hold their post, and
the first period-correct device in the game (the eagle on Sancho VII's seal),
with the chains flagged as later tradition.

## Milestone 4: the other battles and the campaign

Each battle is mostly a JSON file plus a map. The engine work each needs:

| Battle | Player | Map | New rules |
| --- | --- | --- | --- |
| **Covadonga (c. 722)** | Astur-Leonese (Pelayo) vs Umayyad expedition | Narrow valley in the Picos de Europa, cave stronghold at the head | `stronghold` cell: defence bonus, leader bonus, and holding it at nightfall wins. Ambush on for the player. Narration flags the miracle stories (the Chronicle of Alfonso III, written some 160 years later) as legend, and says the Arabic sources are brief and dismissive. |
| **Roncesvalles (778)** | Vascones vs Frankish rearguard | Done | — |
| **Simancas (939)** | León + Pamplona vs the Caliphate | Open ground by the Duero, with fords | `ford` terrain (costly, defended), **mixed armies** (a side fields two factions' units), and an **omen** event at turn 0: the solar eclipse of 19 July 939 lowers both armies' morale at random, and leaders can spend turn 1 rallying. Umayyad palace guard and archers come into play. |

Campaign: the three battles linked by narrated cutscenes over an ink-and-wash
map of the peninsula, with borders redrawn per date (722 / 778 / 939). Build it
as an SVG with one layer per date, cross-fading, and narration from the
scenario JSON. Borders should be drawn as uncertain (washed edges, no hard
lines) where the frontier genuinely was one.

**Custom battle**: any faction vs any on any map, with an adjustable budget.
Everything needed is already data-driven. The work is AI-side point-buy (reuse
`autoDeploy`, and add a roster picker that spends a budget to a role mix),
plus generic deploy zones per map edge. Add every new map and faction pairing
to the balance sweep; the stand-still rule catches degenerate maps.

## Art pass

Replace shapes with paper-cutout silhouettes per role and faction, keeping
the same footprint so the board stays readable. Keep the map illumination:
flat colour bands, bold ink contours between heights (already drawn), and
Beatus-style stylised trees and peaks.
