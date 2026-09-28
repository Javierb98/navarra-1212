import { readFileSync } from 'node:fs';
import { Battle } from '../src/core/battle.js';
import { planTurn } from '../src/core/ai.js';
import { autoDeploy, rosterList } from '../src/core/army.js';

const root = new URL('../', import.meta.url);
const json = (p) => JSON.parse(readFileSync(new URL(p, root), 'utf8'));

export function loadData() {
  const units = json('data/units.json');
  return { rules: json('data/rules.json'), factions: units.factions, units: units.units, taunts: json('data/taunts.json').taunts };
}

export const loadScenario = (id) => json(`data/battles/${id}.json`);

// A battle set up the way a player who took the suggested army and pressed
// "auto-deploy" would get it.
export function standardBattle(data, scenario, seed) {
  const sp = scenario.sides.player;
  const roster = rosterList(sp, sp.suggested);
  return new Battle({
    data,
    scenario,
    seed,
    armies: {
      player: { faction: sp.faction, units: autoDeploy(data, data.rules, scenario, 'player', roster) },
      enemy: { faction: scenario.sides.enemy.faction, units: scenario.sides.enemy.units },
    },
  });
}

// Plays to the end. `player` is 'ai' (a sensible general) or 'still' (holds everything).
export function playOut(battle, player) {
  let guard = 0;
  while (!battle.result && guard++ < 100) {
    if (player === 'ai') planTurn(battle, 'player');
    planTurn(battle, 'enemy');
    battle.resolveTurn();
  }
  return battle.result;
}
