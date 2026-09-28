# Dirección de arte

Written for someone who does not draw. The whole plan is built around that
constraint rather than apologising for it.

## The principle

**Assemble, don't draw.** Pick a style whose assets are *constructed* — from
geometry, from type, from public-domain source material, from shaders — instead
of drawn freehand. Then get visual richness out of motion and light rather than
out of more pictures.

## The style: illuminated chronicle

The game looks like a page of a 13th-century Iberian manuscript: parchment
ground, flat unshaded colour, heavy ink outlines, gold-leaf accents, heraldic
banners, rubricated headings in red.

This is chosen for three reasons, in this order:

1. **Nobody expects manuscript figures to be anatomically good.** Stiff, flat,
   awkwardly proportioned figures with no perspective *are* the aesthetic. The
   style's tolerances are enormous.
2. It is period-correct for Navarre and completely distinctive.
3. The source material is public domain and depicts exactly this subject.

## What already exists

| Asset | Where | Notes |
| --- | --- | --- |
| Palette | `src/ui/palette.gd` | Six colours from a real scriptorium: vellum, iron-gall ink, vermilion, lapis, gold, green earth |
| Parchment ground | `shaders/parchment.gdshader` | Value-noise blotching + grain + vignette. No texture files |
| Faction shields | `assets/heraldry/*.svg` | Ten, all built from rectangles, circles and dashed strokes |
| Screen furniture | `src/ui/chronicle_ui.gd` | Panels, rules, bars, rubricated headings |

The chains of Navarre (`navarra.svg`) are the trick worth noticing: the chain
links are a **dashed stroke**. No link was ever drawn.

## Source material — public domain, and exactly on subject

These are the collections to cut figures from. All are old enough to be in the
public domain as artworks; scans of flat PD artwork are generally PD too, though
individual institutions sometimes claim otherwise, so glance at the terms of
whichever scan you actually download.

- **Cantigas de Santa María** (Alfonso X, c. 1280s, Códice Rico at El Escorial).
  Miniatures of Christian and Andalusi armies, cavalry, sieges, crossbowmen,
  camps. Close to purpose-built for this game.
- **Morgan / Maciejowski Bible** (c. 1250, Morgan Library MS M.638). The best
  medieval combat illustration that exists — mail, spears, horses, melee,
  wounds. High-resolution scans are freely available.
- **Beatus of Liébana** manuscripts (various, 10th–12th c.). Iberian, with
  startling flat colour fields and banded backgrounds. Good for skies, ground
  and abstract panels rather than figures.
- **Wikimedia Commons**, heraldry categories — for any shield you would rather
  not build yourself.

### Making mismatched sources look like one game

This is the step that matters, and it is a shader, not a skill:

1. Cut each figure out (alpha), no colour correction.
2. Run everything through one treatment: **posterise to ~5 levels → tint toward
   the game palette → multiply against the parchment → add a dark ink outline**.
3. Because every figure gets the identical treatment, figures from four
   different manuscripts and three centuries read as one set.

Build it as a `canvas_item` shader alongside `parchment.gdshader` and assign it
to every unit sprite. One shader, whole art style unified.

## Type is half the art

A good face over parchment carries an enormous amount of a screen. Both of
these are SIL Open Font License, free for commercial use, from Google Fonts:

- **Cinzel** — Roman inscriptional capitals. Display, titles, years.
- **EB Garamond** or **Cormorant Garamond** — body and chronicle text.

Drop the `.ttf` files into `assets/fonts/`, then set them as the theme default
in `ChronicleUI` — one place, applies everywhere.

Avoid blackletter (UnifrakturMaguntia and friends). It reads "medieval" to a
modern eye but it is Northern European and centuries late for Navarre; Iberian
manuscripts of this period use Carolingian and Visigothic minuscule.

## Animation without drawing

This is where Godot earns its place over a plainer framework. Ranked by payoff
per hour:

1. **Tweens.** A static figure that slides forward on ADVANCE, jolts on impact,
   tilts and fades on rout reads as fully animated. Zero new art.
2. **Particles.** Arrow volleys, dust, embers, blood — all from a single white
   dot texture, recoloured per emitter.
3. **Shaders.** Ink-bleed dissolve when a company breaks; gold shimmer on the
   commander's ability; a red wash when morale collapses.
4. **Screen shake and hit-stop** on a charge landing. Two lines of code, and the
   single biggest "game feel" upgrade available.
5. **Cutout rigging** (`Skeleton2D` + `Polygon2D`). Rig one soldier once, get
   walk/attack/die without ever drawing a second frame. Do this last — it is the
   only item on the list with real setup cost.

## Fallbacks

- **CC0 asset packs** — [Kenney](https://kenney.nl) for UI and generic medieval
  bits, OpenGameArt filtered to CC0, itch.io CC0 packs. No attribution required,
  though crediting is polite.
- **Geometry.** Anything symmetrical or heraldic can be built rather than drawn.
  Banners, shields, frames, borders, map decoration, unit tokens.
- **Silhouettes.** A solid black spearman silhouette on parchment is both easier
  than a rendered figure and more in keeping with the style.

## What is still needed, in priority order

1. **Fonts.** Cheapest large improvement available. An hour's work.
2. **Unit sprites** — one figure per troop type, five total, cut from the Morgan
   Bible or the Cantigas, run through the unification shader.
3. **The unification shader itself.**
4. **Motion pass on the battle screen** — advance, impact, rout.
5. **Sound.** Not art, but a drum on the round commit and a shout on a rout will
   probably do more for the cabinet than items 2–4 combined.
6. **Campaign map.** Currently a list. A drawn map of Navarre with the seven
   sites marked would be the one genuinely figurative asset worth commissioning
   or tracing.

## Licensing

Keep a note of the source and licence of anything added under `assets/`. Public
domain manuscript scans and CC0 packs need no attribution, but a cabinet in a
public space is a public display, and the difference between CC0 and CC-BY
matters there.
