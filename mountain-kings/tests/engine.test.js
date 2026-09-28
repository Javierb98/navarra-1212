import { test } from 'node:test';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import { Battle } from '../src/core/battle.js';
import { makeRng } from '../src/core/rng.js';
import { autoDeploy, rosterList, validateRoster, deployCells } from '../src/core/army.js';
import { Grid } from '../src/core/grid.js';
import { loadData, loadScenario, standardBattle, playOut } from './helpers.js';

const data = loadData();
const ronc = loadScenario('roncesvalles');

// A small open field for rules tests: row 0 is slope, the rest is road.
const field = {
  turnLimit: 10,
  map: { rows: ['ssssss', '......', '......', '......', '......'] },
  sides: {
    player: { retreat: ['left'], facing: 1, ambush: true, rocks: 2 },
    enemy: { retreat: ['right'], facing: -1 },
  },
};
const fight = (player, enemy, seed = 7, scenario = field) => new Battle({
  data, scenario, seed,
  armies: { player: { faction: 'vascones', units: player }, enemy: { faction: 'franks', units: enemy } },
});

test('rng is deterministic per seed', () => {
  const a = makeRng(42), b = makeRng(42), c = makeRng(43);
  const sa = [a.next(), a.next(), a.next()];
  assert.deepEqual(sa, [b.next(), b.next(), b.next()]);
  assert.notDeepEqual(sa, [c.next(), c.next(), c.next()]);
});

test('every unit type references a known faction and every taunt is bilingual', () => {
  for (const [id, k] of Object.entries(data.units)) assert.ok(data.factions[k.faction], id);
  assert.ok(data.taunts.length >= 40);
  for (const t of data.taunts) assert.ok(t.en && t.es, t.id);
  assert.equal(new Set(data.taunts.map((t) => t.id)).size, data.taunts.length);
});

test('the roncesvalles map parses and its deploy zone is hidden ground plus the road block', () => {
  const g = new Grid(ronc.map.rows, data.rules.terrain);
  assert.equal(g.w, 24);
  const cells = deployCells(g, ronc.sides.player);
  assert.ok(cells.every((c) => c.x >= 11));
  assert.ok(cells.some((c) => c.x === 22 && c.y === 3));
});

test('suggested army fits the budget and auto-deploy places every unit on a legal cell', () => {
  const sp = ronc.sides.player;
  assert.equal(validateRoster(data, sp, sp.suggested), null);
  const roster = rosterList(sp, sp.suggested);
  const placed = autoDeploy(data, data.rules, ronc, 'player', roster);
  assert.equal(placed.length, roster.length);
  assert.equal(new Set(placed.map((p) => `${p.x},${p.y}`)).size, placed.length);
});

test('units deployed on cover start hidden and are revealed by an adjacent enemy', () => {
  const b = fight([{ type: 'vas_warriors', x: 3, y: 0 }], [{ type: 'fra_spearmen', x: 3, y: 3 }]);
  const [v, f] = b.units;
  assert.equal(v.hidden, true);
  assert.equal(f.hidden, false);
  b.setOrder(f.id, { type: 'move', path: [{ x: 3, y: 2 }, { x: 3, y: 1 }] });
  const ev = b.resolveTurn();
  assert.equal(v.hidden, false);
  assert.ok(ev.some((e) => e.t === 'reveal' && e.id === v.id));
});

test('the enemy cannot see or target hidden units', () => {
  const b = fight([{ type: 'vas_warriors', x: 3, y: 0 }], [{ type: 'fra_spearmen', x: 3, y: 2 }]);
  const f = b.units[1];
  assert.equal(b.options(f).melee.length, 0);
  assert.equal(b.options(f).shots.length, 0);
});

test('a first strike from hiding hits much harder and shakes the target', () => {
  const run = (hidden) => {
    const b = fight([{ type: 'vas_warriors', x: 2, y: 0 }], [{ type: 'fra_spearmen', x: 2, y: 1 }], 11);
    const [v, f] = b.units;
    v.hidden = hidden;
    b.setOrder(v.id, { type: 'attack', targetId: f.id });
    const ev = b.resolveTurn();
    const hit = ev.find((e) => e.t === 'strike' && e.a === v.id);
    return { hit, morale: f.morale };
  };
  const amb = run(true), open = run(false);
  assert.ok(amb.hit.ambush);
  assert.ok(amb.hit.mods.includes('ambush'));
  assert.ok(amb.hit.dmg > open.hit.dmg);
  assert.ok(amb.morale < open.morale - 15);
});

test('three shield-wall infantry stacked vertically form a wall that blunts a charge', () => {
  const wall = [{ type: 'fra_spearmen', x: 3, y: 1 }, { type: 'fra_spearmen', x: 3, y: 2 }, { type: 'fra_spearmen', x: 3, y: 3 }];
  const b = fight([{ type: 'vas_horse', x: 0, y: 2 }], wall);
  const mid = b.units[2];
  assert.ok(b.inShieldWall(mid));
  assert.equal(b.formations('enemy').walls.size, 3);
  const p = b.preview(b.units[0], mid, 'melee', { x: 2, y: 2 });
  assert.ok(p.mods.includes('shieldWall'));
  assert.ok(!p.mods.includes('charge'));
  // Break the column and the wall is gone.
  b.units[3].x = 4;
  assert.ok(!b.inShieldWall(mid));
});

test('cavalry that moves two or more cells on the flat charges', () => {
  const b = fight([{ type: 'vas_horse', x: 0, y: 2 }], [{ type: 'fra_spearmen', x: 4, y: 2 }]);
  const p = b.preview(b.units[0], b.units[1], 'melee', { x: 3, y: 2 });
  assert.ok(p.mods.includes('charge'));
});

test('slopes defend, slow the Franks and stop horse charging uphill', () => {
  const b = fight([{ type: 'vas_warriors', x: 3, y: 0 }], [{ type: 'fra_horsemen', x: 0, y: 1 }, { type: 'fra_spearmen', x: 5, y: 4 }]);
  const [v, h, s] = b.units;
  v.hidden = false;
  assert.equal(b.moveCost(v, 2, 0), 1, 'Vascones cross slopes at road speed');
  assert.equal(b.moveCost(s, 2, 0), 3, 'Frankish foot pay double plus one');
  const p = b.preview(h, v, 'melee', { x: 3, y: 1 });
  assert.ok(p.mods.includes('height'));
  assert.ok(p.mods.includes('uphill'));
  assert.ok(p.mods.includes('horseOnSlope'));
  assert.ok(!p.mods.includes('charge'));
});

test('killing the leader drops the whole army\'s morale', () => {
  const b = fight([{ type: 'vas_warriors', x: 2, y: 2 }], [{ type: 'fra_commander', x: 3, y: 2 }, { type: 'fra_spearmen', x: 5, y: 4 }]);
  const [, roland, sp] = b.units;
  roland.hp = 1;
  const before = sp.morale;
  b.setOrder(b.units[0].id, { type: 'attack', targetId: roland.id });
  const ev = b.resolveTurn();
  assert.equal(roland.status, 'dead');
  assert.ok(ev.some((e) => e.t === 'leaderFell'));
  assert.ok(sp.morale <= before - 25);
});

test('capturing a wagon counts for the convoy objective and hurts morale', () => {
  const sc = { ...field, objective: { type: 'convoy', side: 'enemy', exit: [[5, 2]] } };
  const b = fight([{ type: 'vas_warriors', x: 1, y: 2 }], [{ type: 'fra_baggage', x: 2, y: 2 }, { type: 'fra_spearmen', x: 4, y: 4 }], 3, sc);
  const [v, w, sp] = b.units;
  w.hp = 1;
  b.setOrder(v.id, { type: 'attack', targetId: w.id });
  b.resolveTurn();
  assert.equal(w.status, 'captured');
  assert.equal(b.sides.enemy.convoy.captured, 1);
  assert.ok(sp.morale < sp.maxMorale);
  assert.equal(b.result?.winner, 'player');
  assert.equal(b.result?.reason, 'convoyTaken');
});

test('broken units rout and flee toward their own edge', () => {
  const b = fight([{ type: 'vas_warriors', x: 4, y: 2 }], [{ type: 'fra_spearmen', x: 5, y: 3 }]);
  const v = b.units[0];
  v.morale = 1;
  b.setOrder(b.units[1].id, { type: 'taunt' });
  b.resolveTurn();
  // Routed during the taunt phase, it runs in the same turn's movement phase.
  assert.equal(v.status, 'routing');
  assert.ok(v.x < 4);
  assert.ok(b.options(v).reach.size === 0, 'routing units take no orders');
});

test('rocks need height and run out', () => {
  const b = fight([{ type: 'vas_warriors', x: 2, y: 0 }], [{ type: 'fra_spearmen', x: 2, y: 1 }, { type: 'fra_spearmen', x: 5, y: 4 }]);
  const [v, f] = b.units;
  assert.equal(b.options(v).rocks.length, 1);
  b.setOrder(v.id, { type: 'rock', targetId: f.id });
  const ev = b.resolveTurn();
  assert.ok(ev.some((e) => e.t === 'strike' && e.mode === 'rock'));
  assert.equal(b.sides.player.rocks, 1);
});

test('a taunt needs no target and lowers the morale of the whole enemy army', () => {
  const b = fight([{ type: 'vas_warriors', x: 1, y: 2 }], [{ type: 'fra_spearmen', x: 3, y: 2 }, { type: 'fra_spearmen', x: 5, y: 0 }]);
  const [v, near, far] = b.units;
  b.setOrder(v.id, { type: 'taunt' });
  const ev = b.resolveTurn();
  const tt = ev.find((e) => e.t === 'taunt');
  assert.ok(data.taunts.some((x) => x.id === tt.taunt));
  // Judge the taunt itself, before end-of-turn recovery tops morale back up.
  const hurt = (u) => -ev.filter((e) => e.t === 'morale' && e.id === u.id && e.reason === 'taunt').reduce((a, e) => a + e.delta, 0);
  assert.ok(hurt(near) > 0 && hurt(far) > 0, 'every enemy company hears it');
  assert.ok(hurt(near) > hurt(far), 'those in earshot take it hardest');
});

test('hit-and-run units strike and fall back the same turn', () => {
  const b = fight([{ type: 'vas_horse', x: 0, y: 2 }], [{ type: 'fra_spearmen', x: 3, y: 2 }]);
  const [h, f] = b.units;
  b.setOrder(h.id, { type: 'attack', targetId: f.id, withdraw: true });
  const ev = b.resolveTurn();
  assert.ok(ev.some((e) => e.t === 'strike' && e.a === h.id));
  assert.ok(h.x < 2, `withdrew to ${h.x}`);
});

test('invalid orders are refused', () => {
  const b = fight([{ type: 'vas_warriors', x: 0, y: 2 }], [{ type: 'fra_spearmen', x: 5, y: 4 }]);
  assert.throws(() => b.setOrder(b.units[0].id, { type: 'attack', targetId: b.units[1].id }));
  assert.throws(() => b.setOrder(b.units[0].id, { type: 'rally' }));
});

test('same seed, same battle: the engine is deterministic', () => {
  const run = () => {
    const b = standardBattle(data, ronc, 99);
    const log = [];
    playOut(b, 'ai');
    return JSON.stringify([b.result, b.units.map((u) => [u.x, u.y, u.hp, u.status])]);
  };
  assert.equal(run(), run());
});

test('a wagon with a formed escort beside it is guarded', () => {
  const b = fight([{ type: 'vas_warriors', x: 1, y: 2 }], [{ type: 'fra_baggage', x: 2, y: 2 }, { type: 'fra_spearmen', x: 2, y: 3 }]);
  const [v, w, sp] = b.units;
  assert.ok(b.isGuarded(w));
  const guarded = b.preview(v, w, 'melee').damage;
  sp.x = 5;
  assert.ok(!b.isGuarded(w));
  assert.ok(b.preview(v, w, 'melee').damage > guarded);
});

test('the ambush bonus is spent after the first strike, even if the unit hides again', () => {
  const b = fight([{ type: 'vas_warriors', x: 2, y: 0 }], [{ type: 'fra_spearmen', x: 2, y: 1 }, { type: 'fra_spearmen', x: 5, y: 4 }]);
  const [v, f] = b.units;
  b.setOrder(v.id, { type: 'attack', targetId: f.id });
  b.resolveTurn();
  v.hidden = true;
  b.setOrder(v.id, { type: 'attack', targetId: f.id });
  const ev = b.resolveTurn();
  assert.ok(!ev.find((e) => e.t === 'strike' && e.a === v.id).ambush);
});

test('orders are carried out one company at a time, alternating sides, in the order given', () => {
  const b = fight(
    [{ type: 'vas_warriors', x: 0, y: 1 }, { type: 'vas_warriors', x: 0, y: 3 }],
    [{ type: 'fra_spearmen', x: 5, y: 1 }, { type: 'fra_spearmen', x: 5, y: 3 }]);
  const [p0, p1, e0, e1] = b.units;
  // Given p1 first, then p0.
  b.setOrder(p1.id, { type: 'move', path: [{ x: 1, y: 3 }] });
  b.setOrder(p0.id, { type: 'move', path: [{ x: 1, y: 1 }] });
  b.setOrder(e0.id, { type: 'move', path: [{ x: 4, y: 1 }] });
  b.setOrder(e1.id, { type: 'move', path: [{ x: 4, y: 3 }] });
  const acts = b.resolveTurn().filter((e) => e.t === 'act').map((e) => e.ids[0]);
  assert.deepEqual(acts, [p1.id, e0.id, p0.id, e1.id], 'turn 1: player first');
  b.setOrder(p0.id, { type: 'move', path: [{ x: 2, y: 1 }] });
  b.setOrder(e0.id, { type: 'move', path: [{ x: 3, y: 1 }] });
  const acts2 = b.resolveTurn().filter((e) => e.t === 'act').map((e) => e.ids[0]);
  assert.deepEqual(acts2, [e0.id, p0.id], 'turn 2: enemy first');
});

test('a formation moves together in one slot and forms a shield wall', () => {
  const b = fight(
    [{ type: 'vas_warriors', x: 0, y: 1 }, { type: 'vas_warriors', x: 0, y: 2 }, { type: 'vas_warriors', x: 1, y: 4 }],
    [{ type: 'fra_spearmen', x: 5, y: 4 }]);
  const [a, c, d] = b.units;
  const path = (u, x, y) => b.pathOf(b.reachable(u, new Set([a.id, c.id, d.id])).get(b.grid.key(x, y)));
  b.setGroupOrders([
    { id: a.id, order: { type: 'move', path: path(a, 2, 1) } },
    { id: c.id, order: { type: 'move', path: path(c, 2, 2) } },
    { id: d.id, order: { type: 'move', path: path(d, 2, 3) } },
  ]);
  const ev = b.resolveTurn();
  assert.equal(ev.filter((e) => e.t === 'act' && e.side === 'player').length, 1);
  assert.ok(b.inShieldWall(c), 'three stacked spear companies make a wall');
});

test('three companies of foot in an arrowhead make a V, and its point hits harder', () => {
  const b = fight(
    [{ type: 'vas_warriors', x: 2, y: 2 }, { type: 'vas_warriors', x: 1, y: 1 }, { type: 'vas_warriors', x: 1, y: 3 }],
    [{ type: 'fra_spearmen', x: 3, y: 2 }]);
  const [tip, , , foe] = b.units;
  assert.equal(b.isWedgeTip(tip), 1);
  assert.ok(b.preview(tip, foe, 'melee').mods.includes('wedge'));
});

test('hit-and-run only falls back when ordered to', () => {
  const b = fight([{ type: 'vas_horse', x: 0, y: 2 }], [{ type: 'fra_spearmen', x: 3, y: 2 }]);
  const [hh, f] = b.units;
  b.setOrder(hh.id, { type: 'attack', targetId: f.id });
  b.resolveTurn();
  assert.equal(hh.x, 2, 'stays in contact without the order');
});

test('an aimed volley hits whatever is where it lands: enemy, friend, or nothing', () => {
  const setup = () => fight(
    [{ type: 'vas_skirmishers', x: 0, y: 2 }, { type: 'vas_warriors', x: 1, y: 2 }],
    [{ type: 'fra_spearmen', x: 2, y: 2 }]);
  const run = (aim) => {
    const b = setup();
    const [s, w, f] = b.units;
    b.setOrder(s.id, { type: 'shoot', targetId: f.id });
    const it = b.turnSteps({ interactive: ['player'] });
    let r = it.next();
    assert.equal(r.value.request.kind, 'aim');
    // The volley runs along the row to the edge of the field.
    assert.deepEqual(r.value.request.line.map((c) => [c.x, c.k]), [[1, 1], [2, 2], [3, 3], [4, 4], [5, 5]]);
    while (!r.done) r = it.next(aim);
    return { ev: b.ev, w, f };
  };
  const on = run({ k: 2, quality: 1 });
  assert.equal(on.ev.find((e) => e.t === 'volley').result, 'hit');
  assert.ok(on.f.hp < on.f.maxHp);
  const short = run({ k: 1, quality: 1 });
  assert.equal(short.ev.find((e) => e.t === 'volley').result, 'friendly');
  assert.ok(short.w.hp < short.w.maxHp, 'short volley lands on our own warriors');
  const long = run({ k: 3, quality: 1 });
  assert.equal(long.ev.find((e) => e.t === 'volley').result, 'miss');
  assert.equal(long.f.hp, long.f.maxHp);
});

test('resolveTurn aims automatically and never pauses', () => {
  const b = fight([{ type: 'vas_skirmishers', x: 0, y: 2 }], [{ type: 'fra_spearmen', x: 2, y: 2 }]);
  b.setOrder(b.units[0].id, { type: 'shoot', targetId: b.units[1].id });
  const ev = b.resolveTurn();
  assert.ok(ev.some((e) => e.t === 'volley'));
});

test('missile companies fire along their row with no range limit, moving into a row first if needed', () => {
  const b = fight([{ type: 'vas_skirmishers', x: 0, y: 2 }], [{ type: 'fra_spearmen', x: 5, y: 2 }, { type: 'fra_spearmen', x: 4, y: 4 }]);
  const [s, same, other] = b.units;
  const along = b.options(s).shots.find((e) => e.target.id === same.id);
  assert.ok(along && along.via.cost === 0, 'anything down the row can be shot from here');
  const across = b.options(s).shots.find((e) => e.target.id === other.id);
  assert.ok(across && across.via.cost > 0 && across.via.y === 4, 'another row means moving into it');
  b.setOrder(s.id, { type: 'shoot', targetId: other.id, path: b.pathOf(across.via) });
  const ev = b.resolveTurn();
  assert.ok(ev.some((e) => e.t === 'steps' && e.moves[0].id === s.id));
  assert.ok(ev.some((e) => e.t === 'volley'));
  assert.ok(b.missileOf(s) > b.attackOf(s));
});

test('everything the player reads has an English and a Spanish version', () => {
  const strings = JSON.parse(readFileSync(new URL('../data/strings.json', import.meta.url), 'utf8'));
  assert.deepEqual(Object.keys(strings.en).sort(), Object.keys(strings.es).sort());
  const walk = (o, path) => {
    if (Array.isArray(o)) return o.forEach((v, i) => walk(v, `${path}[${i}]`));
    if (o && typeof o === 'object') {
      if ('en' in o) assert.ok(o.es, `no Spanish for ${path}`);
      for (const [k, v] of Object.entries(o)) if (!k.startsWith('_')) walk(v, `${path}.${k}`);
    }
  };
  walk(data.factions, 'factions');
  walk(data.units, 'units');
  walk(data.taunts, 'taunts');
  for (const id of ['covadonga', 'roncesvalles', 'simancas', 'las_navas']) {
    const sc = loadScenario(id);
    walk(sc, id);
    for (const src of sc.sources) assert.ok(src.en && src.es, `${id}: sources are bilingual`);
    for (const para of [sc.briefing.en, sc.briefing.es]) assert.equal(para.length, sc.cutscene.steps.length, `${id}: one caption per map step`);
  }
});

test('a split volley hurts each company in proportion to the share that struck it', () => {
  const b = fight(
    [{ type: 'vas_skirmishers', x: 0, y: 2 }, { type: 'vas_warriors', x: 1, y: 2 }],
    [{ type: 'fra_spearmen', x: 2, y: 2 }]);
  const [s, w, f] = b.units;
  b.setOrder(s.id, { type: 'shoot', targetId: f.id });
  const it = b.turnSteps({ interactive: ['player'] });
  let r = it.next();
  r = it.next({ hits: [{ k: 2, frac: 0.4 }, { k: 1, frac: 0.15 }] });
  while (!r.done) r = it.next(null);
  const v = b.ev.find((e) => e.t === 'volley');
  assert.equal(v.result, 'hit');
  assert.equal(v.spread.length, 2);
  assert.ok(f.hp < f.maxHp && w.hp < w.maxHp);
  assert.ok(f.maxHp - f.hp > w.maxHp - w.hp, 'more of the volley hit the enemy');
});

test('companies near their leader hold; far or leaderless ones break more easily', () => {
  const b = fight([{ type: 'vas_chief', x: 0, y: 2 }, { type: 'vas_warriors', x: 1, y: 2 }, { type: 'vas_warriors', x: 5, y: 0 }], [{ type: 'fra_spearmen', x: 5, y: 4 }]);
  const [chief, near, far] = b.units;
  assert.equal(b.command(near), 'in');
  assert.equal(b.command(far), 'out');
  const m0 = near.morale, f0 = far.morale;
  b.changeMorale(near, -20, 'hit');
  b.changeMorale(far, -20, 'hit');
  assert.ok(m0 - near.morale < f0 - far.morale, 'the company by its leader lost less');
  chief.status = 'dead';
  assert.equal(b.command(near), 'leaderless');
  assert.ok(b.lossFactor(near) > b.lossFactor(far) || b.lossFactor(near) > 1.2);
});

test('minigames: a charge, a fight and a taunt each pause the turn and scale the result', () => {
  const run = (kind, answer) => {
    const b = fight(
      kind === 'charge' ? [{ type: 'vas_horse', x: 0, y: 2 }] : [{ type: 'vas_warriors', x: kind === 'taunt' ? 1 : 2, y: 2 }],
      [{ type: 'fra_spearmen', x: 3, y: 2 }], 5);
    const [p, e] = b.units;
    b.setOrder(p.id, kind === 'taunt' ? { type: 'taunt' } : { type: 'attack', targetId: e.id });
    const it = b.turnSteps({ interactive: ['player'] });
    let r = it.next();
    const req = r.value.request;
    while (!r.done) r = it.next(answer);
    return { req, e };
  };
  const strong = run('charge', { power: 1 }), weak = run('charge', { power: 0 });
  assert.equal(strong.req.kind, 'charge');
  assert.ok(strong.e.hp < weak.e.hp, 'mashing hard hits harder');
  const good = run('melee', { score: 1 }), bad = run('melee', { score: 0 });
  assert.equal(good.req.kind, 'melee');
  assert.ok(good.e.hp < bad.e.hp, 'fighting well hits harder');
  const sharp = run('taunt', { score: 1 }), fluffed = run('taunt', { score: 0 });
  assert.equal(sharp.req.kind, 'taunt');
  assert.ok(sharp.req.taunt);
  assert.ok(sharp.e.morale < fluffed.e.morale, 'a well-typed insult stings more');
});

test('courage bends with the situation: flanks, the rear, being outnumbered, heavy losses', () => {
  const lossFrom = (setup) => {
    const b = fight([{ type: 'vas_warriors', x: 2, y: 2 }], setup, 3);
    const [v] = b.units;
    b.units[1].x === 3 && (v.facing = 1);
    const before = v.morale;
    for (const e of b.units.slice(1)) b.takeBlow(v, e, 4);
    return { lost: before - v.morale, reasons: b.ev.filter((e) => e.t === 'morale').map((e) => e.reason) };
  };
  const front = lossFrom([{ type: 'fra_spearmen', x: 3, y: 2 }]);
  const flank = lossFrom([{ type: 'fra_spearmen', x: 2, y: 1 }]);
  const rear = lossFrom([{ type: 'fra_spearmen', x: 1, y: 2 }]);
  const mobbed = lossFrom([{ type: 'fra_spearmen', x: 3, y: 2 }, { type: 'fra_spearmen', x: 2, y: 1 }, { type: 'fra_spearmen', x: 2, y: 3 }]);
  assert.ok(flank.reasons.includes('flanked') && flank.lost > front.lost);
  assert.ok(rear.reasons.includes('rear') && rear.lost > flank.lost);
  assert.ok(mobbed.reasons.includes('overwhelmed'));
  const b = fight([{ type: 'vas_warriors', x: 2, y: 2 }], [{ type: 'fra_spearmen', x: 3, y: 2 }]);
  b.units[0].turnLoss = 0;
  b.takeBlow(b.units[0], b.units[1], 12);
  assert.ok(b.ev.some((e) => e.reason === 'heavyLosses'), 'a third of the company gone in one turn shakes it');
});

test('custom battles: any people against any, on every field, play to a result', async () => {
  const { customScenario, FIELD_MAP, validateRoster } = await import('../src/core/army.js');
  const peoples = Object.keys(data.factions);
  const bases = [FIELD_MAP, ...['covadonga', 'roncesvalles', 'simancas', 'las_navas'].map(loadScenario)];
  let played = 0;
  for (const base of bases) {
    for (const player of peoples) {
      for (const enemy of peoples) {
        if (player === enemy && base !== FIELD_MAP) continue;
        const sc = customScenario(data, data.rules, { base, player, enemy, budget: 700, hidden: true });
        assert.equal(validateRoster(data, sc.sides.player, sc.sides.player.suggested), null, `${player} roster`);
        assert.ok(sc.sides.enemy.units.length >= 4, `${enemy} army deployed on ${base.id}`);
        const r = playOut(standardBattle(data, sc, 17 + played), 'ai');
        assert.ok(r && r.reason, `${player} v ${enemy} on ${base.id} ended`);
        played++;
      }
    }
  }
  assert.ok(played > 60);
});
