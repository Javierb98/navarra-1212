// Balance sweep. Plays every battle many times with a sensible player and with
// a player who never gives an order. The first must usually win; the second
// must never win. If you change a number in data/ and skip this, you are
// guessing.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { loadData, loadScenario, standardBattle, playOut } from './helpers.js';

const data = loadData();
const RUNS = 16;

for (const id of ['covadonga', 'roncesvalles', 'simancas', 'las_navas']) {
  const scenario = loadScenario(id);

  test(`${id}: winnable by playing sensibly`, () => {
    let wins = 0;
    const reasons = {};
    for (let seed = 1; seed <= RUNS; seed++) {
      const r = playOut(standardBattle(data, scenario, seed * 7919), 'ai');
      if (r.winner === 'player') wins++;
      reasons[`${r.winner}:${r.reason}`] = (reasons[`${r.winner}:${r.reason}`] ?? 0) + 1;
    }
    console.log(`  ${id} sensible: ${wins}/${RUNS}`, reasons);
    assert.ok(wins >= RUNS * 0.6, `only ${wins}/${RUNS} wins`);
    assert.ok(wins < RUNS, 'never lost: too easy, or the enemy AI is broken');
  });

  test(`${id}: not winnable by standing still`, () => {
    let wins = 0;
    const reasons = {};
    for (let seed = 1; seed <= RUNS; seed++) {
      const r = playOut(standardBattle(data, scenario, seed * 104729), 'still');
      if (r.winner === 'player') wins++;
      reasons[`${r.winner}:${r.reason}`] = (reasons[`${r.winner}:${r.reason}`] ?? 0) + 1;
    }
    console.log(`  ${id} standing still: ${wins}/${RUNS}`, reasons);
    assert.equal(wins, 0);
  });
}
