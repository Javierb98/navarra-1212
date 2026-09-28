# Diseño

How the game works, why it works that way, and every number you can turn.

## The loop

```
attract → campaña → informe → batalla → crónica final → campaña
```

A battle is a handful of rounds. Each round the player gives an order to every
company, then commits the whole line at once; the enemy captain has chosen at
the same time, in the dark. Everything resolves simultaneously.

That simultaneity is the design's load-bearing wall. It means the interesting
question is never "what is the optimal move against this board" but "what do I
think the other captain is about to do", and it means the AI can never be
accused of cheating by reacting to a choice it has already seen.

## Morale is the health bar

Companies are not destroyed, they are broken. A routed company walks off the
field with most of its men alive and takes a piece of everyone else's nerve
with it. Army morale is the weighted average across every company (routed ones
counting zero); below the scenario's threshold, the army quits.

This is both the *1066* lesson and the historically honest one — medieval
battles were decided by one side deciding to stop, usually well before it had
been killed.

There is no rallying. A broken company is gone. That keeps a collapsing wing
legible at arcade speed.

## The triangle

```
peones (spears)  ──stop──▶  caballería (heavy horse)
caballería       ──ride down──▶  ballesteros (crossbows)
ballesteros      ──shred──▶  peones
```

Two extra types sit off the triangle to give later battles their own texture:

- **almogávares** — light foot, excellent on broken ground, weak in the open.
- **jinetes** — light horse, fight by withdrawing and coming back.

Both are deliberately *weaker head-on* than the core three. They are
situational, not upgrades.

The single most important interaction is spelled out as an explicit rule rather
than left to the multipliers: **spears on MANTENER against an incoming CARGAR
double their defence** (`Orders.BRACE_BONUS`). Everything else in the triangle
hangs off that being reliably true, and there is a test for it.

## The five orders

| Order | atk | def | fatigue | morale |
| --- | --- | --- | --- | --- |
| Mantener (hold) | 0.60 | 1.40 | −8 | +2.5 |
| Avanzar (advance) | 1.00 | 1.00 | +6 | 0 |
| Cargar (charge) | 1.70 | 0.70 | +18 | +2 |
| Hostigar (skirmish) | 0.90 | 1.20 | +4 | 0 |
| Replegarse (fall back) | 0.00 | 0.80 | −14 | +10 |

Only missile troops may skirmish. Skirmishers that get caught in melee fight at
35% — otherwise HOSTIGAR would pay twice in a round, once at range and again in
the clash.

Five orders is the whole player-facing decision space, and that is on purpose:
an arcade player reads this from two metres away with a joystick in their hand.
Depth comes from the interaction with unit type, fatigue and the enemy's
simultaneous choice, not from menu breadth.

## Weariness — why battles end

An early version of the engine deadlocked. Two armies both playing carefully
settled into a plateau where morale regeneration exactly cancelled casualties,
and the battle ran out of rounds with both sides at 60% — which is neither good
history nor a good arcade game. Atapuerca was unwinnable by anyone.

The fix is `Battle.WEARINESS_FROM_ROUND` / `WEARINESS_PER_ROUND`: from round 4,
simply standing in the line costs every company nerve, and the cost grows each
round. It forces a decision, it rewards winning quickly, and it matches what
actually exhausted medieval armies.

Holding was also nerfed at the same time (morale recovery 6 → 2.5). Recovery
belongs to REPLEGAR, which costs you ground for it. When holding both tanked
damage *and* healed, standing still was the answer to every question.

## Tuning knobs

Combat constants, `src/core/`:

| Constant | File | Effect |
| --- | --- | --- |
| `SHOCK` (1.35) | battle.gd | how hard casualties bite morale. Higher = shorter, more brittle battles |
| `WEARINESS_PER_ROUND` (0.9) | battle.gd | how fast a long battle decays |
| `FLANK_BONUS` (1.25) | battle.gd | reward for hitting an unopposed wing |
| `ROUT_SHOCK_*` | battle.gd | how much a company breaking scares its neighbours |
| `BRACE_BONUS` (2.0) | orders.gd | spears vs charge |
| `STATS` / `COUNTER` | unit_kind.gd | the troop types and the triangle |

Per-scenario knobs are in the JSON — see the schema below.

**Always run the balance sweep after touching any of these:**

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
    --script tests/test_battle.gd
```

It asserts every battle is winnable playing sensibly and none is winnable by
standing still, and prints the win rates.

## The enemy captain

`src/core/battle_ai.gd` scores each legal order with readable heuristics and
picks with weighted randomness, so there is always a floor chance of a bad
order. Two dials per scenario:

- `agresividad` (0–1) — appetite for closing and charging.
- `astucia` (0–1) — how well it reads matchups and its own condition. At 0 it
  more or less flails; at 1 it braces spears against horse, keeps crossbows
  away from cavalry, and pulls broken companies out of the line.

It is deliberately not optimal. A player should be able to learn its habits
over a few plays.

It uses the battle's own RNG, so a seeded battle replays identically — which
is what makes the balance sweep meaningful and what a replay or attract-mode
demo would need later.

## Scenario JSON

`data/battles/<id>.json`. Everything about a battle lives here; adding one
needs no code, only a new file and its id in `GameState.CAMPAIGN`.

```jsonc
{
  "id": "navas_de_tolosa_1212",
  "anio": 1212,
  "titulo": "…", "lugar": "…", "fecha": "…",
  "resumen": "briefing prose",
  "nota_historica": "what actually happened, shown after the battle",
  "advertencia": "legend-vs-record warning; omit or leave empty if none",
  "fuentes": ["…"],

  "bando_jugador": { "nombre": "…", "color": "#8c2f1f",
                     "heraldica": "res://assets/heraldry/navarra.svg" },
  "bando_enemigo": { … },

  "comandante": {
    "nombre": "Sancho VII el Fuerte",
    "habilidad": "Romper las cadenas",
    "habilidad_desc": "shown on the briefing page",
    "efecto": "carga"        // carga | muro | emboscada | moral
  },

  "terreno": {
    "nombre": "…", "desc": "…",
    "mods": { "caballeria": 0.5, "almogavares": 1.3 },  // per troop type
    "alas": [1.1, 0.9, 1.1]                             // per wing
  },

  "rondas_max": 10,
  "umbral_ruptura": 24,           // player army morale floor
  "umbral_ruptura_enemigo": 34,   // optional; defaults to the same figure
  "objetivo": { "tipo": "objetivo_unidad", "unidad": "alm_guardia" },
  "ia": { "agresividad": 0.6, "astucia": 0.8 },

  "unidades_jugador": [
    { "id": "nav_sancho", "nombre": "Mesnada de Sancho el Fuerte",
      "tipo": "caballeria",       // peones|ballesteros|caballeria|almogavares|jinetes
      "ala": 1,                   // 0 left, 1 centre, 2 right
      "fuerza": 320, "moral": 100,
      "mod_ataque": 1.2, "mod_moral": 1.4 }
  ],
  "unidades_enemigo": [ … ]
}
```

**Objective types**

- `romper` — break the enemy army. The default.
- `sobrevivir` — reach round `valor` without your own army breaking. Used for
  battles that were historically defeats.
- `objetivo_unidad` — rout the company with id `unidad`. Used for the sieges
  and for Las Navas.

**Commander abilities** (one use per battle)

- `carga` — your charges hit for +60% this round.
- `muro` — your defence ×1.8 this round.
- `emboscada` — your damage ×2 this round.
- `moral` — +30 morale to every company, applied immediately.

**Two ordering rules that matter**

1. Companies in the same wing fight in array order — the first one listed holds
   the front, and the ones behind it feed in as it breaks. At Las Navas the
   stake palisade is listed *before* the chained guard so the player has to
   break through it to reach the objective.
2. Per-side break thresholds exist because armies do not all break at the same
   point. A king's household stands where a coalition of unwilling levies runs.
   At Las Navas the huge Almohad host has a *higher* floor than the small
   Navarrese one, which is both what the sources describe and what makes the
   finale hard.

## Why the screens are built in code

There is no `.tscn` layout to speak of — every screen is assembled by its
script from `src/ui/chronicle_ui.gd` builders. While the art direction is still
moving, having the styling in exactly one place is worth more than being able
to drag boxes around. `tests/test_screens.gd` exists because this trade means a
layout typo is a runtime error rather than a parse error.

If you later want to build screens visually in the editor, keep calling
`ChronicleUI.page()` for the ground and the rest will still match.

## Open questions

- **Sound.** Nothing yet. A drum for the round commit and a shout for a rout
  would probably do more for feel than any amount of new art.
- **Animation.** The board is static. Companies sliding as they advance and
  falling back as they rout is the obvious first pass — see `docs/ARTE.md`.
- **Two players.** The cabinet panel has room. Simultaneous orders is already
  the right model for hot-seat.
- **Attract-mode demo.** The engine is seeded and deterministic, so replaying a
  recorded battle on the title screen is mostly UI work.
- **Difficulty.** There is no difficulty setting; `astucia` per scenario is
  doing that job implicitly. A cabinet dip-switch that scales it globally would
  be easy.
