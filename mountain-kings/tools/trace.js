// Prints a battle turn by turn as ASCII. Usage: node tools/trace.js [seed] [ai|still]
import { loadData, loadScenario, standardBattle } from '../tests/helpers.js';
import { planTurn } from '../src/core/ai.js';

const seed = Number(process.argv[2] ?? 7919);
const mode = process.argv[3] ?? 'ai';
const data = loadData();
const b = standardBattle(data, loadScenario(process.argv[4] ?? 'roncesvalles'), seed);
const glyph = (u) => {
  const r = u.kind.role;
  let c = { infantry: 'i', cavalry: 'c', skirmisher: 's', ranged: 'r', leader: 'l', wagon: 'w' }[r];
  if (u.side === 'player') c = c.toUpperCase();
  if (u.status === 'routing') c = '!';
  return c;
};
const draw = () => {
  for (let y = 0; y < b.grid.h; y++) {
    let row = '';
    for (let x = 0; x < b.grid.w; x++) {
      const u = b.unitAt(x, y);
      row += u ? (u.hidden ? glyph(u).toLowerCase() === glyph(u) ? glyph(u) : '?' : glyph(u)) : b.grid.codes[y][x] === '.' ? '·' : ' ';
    }
    console.log('  ' + row);
  }
};
draw();
while (!b.result) {
  if (mode === 'ai') planTurn(b, 'player');
  planTurn(b, 'enemy');
  const orders = [...b.orders].map(([id, o]) => `${id}:${o.type}${o.targetId ? '>' + o.targetId : ''}`).join(' ');
  const ev = b.resolveTurn();
  console.log(`turn ${b.result ? b.turn : b.turn - 1}: ${orders}`);
  for (const e of ev) {
    if (e.t === 'strike') console.log(`   ${e.a} ${e.mode} ${e.d} -${e.dmg} (hp ${e.hp}) ${e.mods.join(',')}`);
    else if (['rout', 'dead', 'captured', 'escaped', 'fled', 'reveal', 'leaderFell', 'rallied', 'end', 'short'].includes(e.t)) console.log('   ', JSON.stringify(e));
  }
  draw();
}
console.log(b.result, b.sides.enemy.convoy);
