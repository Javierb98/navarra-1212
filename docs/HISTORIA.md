# Historia y fuentes

The history is the content of this game, so it gets the same care as the code.
This document records what each battle rests on, and — more importantly — where
the game is guessing, simplifying, or repeating a legend.

## Sourcing rules

Every scenario JSON has three prose fields, and they are not interchangeable:

- **`resumen`** — the briefing. Dramatised, second person, sets up the tactical
  problem. This is allowed to be vivid.
- **`nota_historica`** — shown *after* the battle. What the sources actually
  record. No dramatisation, no invented detail, no motives nobody wrote down.
- **`advertencia`** — shown only when there is something to warn about: a
  popular story that is legend rather than record, or a framing that misleads.
  Leave it empty when there is nothing to say. It loses its force if every
  battle has one.

The rule of thumb: if a player looked something up after playing, they should
find the game was straight with them.

## The seven battles

### 778 · Roncesvalles

Charlemagne, returning from a failed expedition to Zaragoza, razed Pamplona's
walls on the way out. His rearguard was destroyed in the Pyrenees by *Wascones*
— Basques, not Muslims. Einhard names three of the dead: Eggihard the royal
seneschal, Anselm the count palatine, and Hruodland, prefect of the Breton
March. Eggihard's epitaph gives the date as 15 August.

*Sources:* Einhard, `Vita Karoli Magni` ch. 9; `Annales regni Francorum` s.a.
778; epitaph of Eggihard.

*Flagged in game:* the `Chanson de Roland` (c. 1100) turns the Basques into
Saracens and an ambush into a battle of heroes. That is literature.

*Gap:* no source names a Basque leader. The scenario's commander is
deliberately anonymous — "Capitanes de la montaña" — rather than inventing one.

### 824 · Second Roncesvalles

Louis the Pious sent counts Aeblus and Aznar Sánchez against Pamplona; the
expedition was destroyed in the same pass by Basques allied with the Banu Qasi
of Tudela. Aeblus was sent as a prisoner to Córdoba; Aznar Sánchez was released
because the Basques recognised him as kin. Afterwards the Franks gave up on the
upper Ebro and Íñigo Arista emerges as the first king of Pamplona.

*Sources:* Ibn Hayyan, `al-Muqtabis`; the Astronomer, `Vita Hludovici` ch. 40;
`Códice de Roda`.

*Flagged in game:* that the first king of Pamplona was propped up by a Muslim
family he was related to by blood is not an awkward exception, it is how the
frontier worked. Musa ibn Musa of the Banu Qasi was Íñigo's maternal
half-brother.

### 920 · Valdejunquera

Abd al-Rahman III's Muez campaign. He beat Sancho Garcés I of Pamplona and
Ordoño II of León in open country on 26 July; bishops Dulcidio of Salamanca and
Hermogius of Tuy were taken prisoner to Córdoba, and the fortress of Muez was
stormed and its garrison executed.

*Sources:* Ibn Hayyan, `al-Muqtabis V`; `Crónica de Sampiro`.

*Why it is in the campaign:* it is a defeat, and it is modelled as one — the
objective is to get the army off the field intact, not to win. A campaign of
nothing but victories teaches a false history of the frontier.

### 923 · Nájera and Viguera

Sancho Garcés I, again with Ordoño II, took Nájera and Viguera and broke Banu
Qasi power on the upper Ebro. The Rioja was absorbed into the kingdom, and
Nájera would become a royal seat. Sancho died in 925.

*Sources:* `Crónica de Sampiro`; Ibn Hayyan, `al-Muqtabis V`; `Códice de Roda`.

*Simplification:* the game compresses a campaign of sieges into one assault on
the citadel of Viguera. Sieges are not really what this combat system models.

### 1054 · Atapuerca

García Sánchez III of Pamplona was killed on 1 September fighting his brother
Fernando I of León and Castile. His son Sancho IV succeeded him and kept the
kingdom, but Navarre lost ground westward and slid into the Castilian orbit.
García was buried at Santa María la Real de Nájera, the church he had founded.

*Sources:* `Crónica najerense`; `Historia Silense`; Rodrigo Jiménez de Rada,
`De rebus Hispaniae` VI.

*Flagged in game:* calling these centuries the "Reconquista" hides how much of
the fighting was Christian kings against each other. Atapuerca is in the
campaign precisely for that.

*Note:* this was historically a Navarrese defeat, and the game lets you replay
it against the grain. The `nota_historica` says what really happened either way.

### 1119 · Tudela

Alfonso I el Batallador took Tudela in February 1119, weeks after Zaragoza. The
Muslim population received a *fuero* letting them stay with their law and
religion, on condition of moving to the outskirts within a year and paying
their tributes.

*Sources:* `Fuero de Tudela` (1119); `Crónica de San Juan de la Peña`; José
María Lacarra, *La reconquista y repoblación del valle del Ebro*.

*Flagged in game:* a frontier of extermination does not match what the
conquerors themselves wrote down.

### 1212 · Las Navas de Tolosa

On 16 July the coalition of Alfonso VIII of Castile, Pedro II of Aragón and
Sancho VII el Fuerte of Navarre destroyed the Almohad army of Muhammad al-Nasir
in the Sierra Morena. Almohad power in the peninsula never recovered; Córdoba
and Seville fell within a generation. Sancho VII's charge into the caliph's
camp is the tradition behind the chains of Navarre.

*Sources:* Rodrigo Jiménez de Rada, `De rebus Hispaniae` VIII — he was present;
Alfonso VIII's letter to Innocent III, 1212; Ibn Idari, `al-Bayan al-Mugrib`;
Martín Alvira Cabrer, *Las Navas de Tolosa 1212*.

*Flagged in game:* **the chains are the legendary part.** They are documented as
the arms of Navarre well after 1212, and heraldists generally derive them from
an earlier device of radiating bars (an *escarbuncle*) for which the battle was
later supplied as an explanation. Sancho VII was there and he charged; that the
shield comes from it is tradition.

The other well-known story from this battle — the shepherd who showed the
Christian army the pass — is likewise later tradition, and the game does not
use it.

## Deliberate anachronisms

Three, all accepted knowingly:

1. **Unit type names.** *Almogávar* is a 12th–14th century term, used here as a
   general class for light mountain infantry, including at Roncesvalles in 778.
   *Ballesteros* covers archers as well as crossbowmen. These are game
   categories, not period unit designations.

2. **Heraldry.** Heraldry proper begins in the 12th century. Every shield in
   `assets/heraldry/` for a battle before ~1100 is an invented identifying
   device so the player can tell the sides apart. The Aragonese pales
   (`batallador.svg`) and the chains (`navarra.svg`) are the only ones close to
   real for their date — and see the caveat about the chains above. Each SVG
   says which it is in a comment.

3. **Company sizes.** Round numbers chosen for play balance. Real figures for
   these battles are mostly unknown and the chronicle numbers are inflated.

## Adding a battle

1. Write `data/battles/<id>.json` — schema in [`DISENO.md`](DISENO.md).
2. Add the id to `GameState.CAMPAIGN` in campaign order.
3. Fill `fuentes` with real citations, and `advertencia` only if there is
   genuinely a legend to separate out.
4. Run the balance sweep; tune until it is winnable playing well and not
   winnable standing still.

## Reading

- Martín Alvira Cabrer, *Las Navas de Tolosa 1212: idea, liturgia y memoria de
  la batalla* — the standard modern account.
- José María Lacarra, *Historia política del reino de Navarra* — the backbone
  for the whole campaign.
- Roger Collins, *The Basques* — for 778 and 824 without the Roland overlay.
- Ibn Hayyan, `al-Muqtabis` (Spanish trans.) — the Córdoban side, which most
  popular accounts of this period simply omit.
