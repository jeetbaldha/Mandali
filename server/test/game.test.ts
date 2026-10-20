import { test } from "node:test";
import assert from "node:assert/strict";
import {
  act,
  addBalance,
  dealHand,
  defaults,
  expire,
  seeCards,
  snapshot,
  startHand,
  vote,
  type Room,
} from "../src/engine/game.js";

function fixture(count = 3): Room {
  return {
    id: "r",
    code: "ABCDEF",
    name: "Test",
    hostId: "p0",
    version: 0,
    settings: { ...defaults },
    players: Array.from({ length: count }, (_, i) => ({
      id: `p${i}`,
      name: `Player ${i}`,
      avatar: "kite",
      seat: i,
      balance: 500,
      active: true,
    })),
    game: null,
    lastDealerSeat: null,
    transactions: [],
  };
}
function started(count = 3) {
  const room = fixture(count);
  room.settings.activeLimit = Math.max(6, count);
  startHand(room, "p0", 1000);
  dealHand(room, "p0", 3, 1001);
  return room;
}
function payRound(room: Room) {
  for (const p of room.game!.players.filter((p) => !p.folded))
    act(room, p.id, "PLAY", room.game!.startTime + 1);
}
function voting(room: Room) {
  payRound(room);
  payRound(room);
  payRound(room);
  act(room, room.game!.pending[0]!, "SHOW", room.game!.startTime + 1);
  expire(room, room.game!.endTime!);
}
test("minimum 3; only dealer can deal; dealer chooses a fitting equal card count", () => {
  const room = fixture(2);
  assert.throws(() => startHand(room, "p0", 0));
  room.players.push({
    id: "p2",
    name: "Third",
    avatar: "sun",
    seat: 2,
    balance: 500,
    active: true,
  });
  startHand(room, "p0", 0);
  assert.throws(() => dealHand(room, "p1", 3, 1));
  assert.throws(() => dealHand(room, "p0", 18, 1));
  dealHand(room, "p0", 17, 1);
  assert.ok(room.game!.players.every((p) => p.cards.length === 17));
});
test("blind hides own cards, See is free, opponents remain private", () => {
  const room = started();
  assert.equal(snapshot(room, "p0", 1002).game!.players[0]!.cards.length, 0);
  act(room, "p0", "BLIND", 1002);
  assert.equal(room.game!.pot, 20);
  assert.equal(snapshot(room, "p0", 1003).game!.players[0]!.cards.length, 0);
  seeCards(room, "p0");
  assert.equal(snapshot(room, "p0", 1004).game!.players[0]!.cards.length, 3);
  assert.equal(snapshot(room, "p1", 1004).game!.players[0]!.cards.length, 0);
  assert.equal(room.game!.pot, 20);
});
test("turn, phase and deadlines reject unauthorized or late actions", () => {
  const room = started();
  assert.throws(() => act(room, "p1", "PLAY", 1002));
  assert.throws(() => act(room, "p0", "SHOW", 1002));
  assert.throws(() => act(room, "p0", "PLAY", room.game!.endTime!));
  assert.equal(room.game!.pot, 0);
});
test("insufficient balance can be topped up without pot inflation", () => {
  const room = started();
  room.players[0]!.balance = 10;
  assert.throws(() => act(room, "p0", "PLAY", 1002), /INSUFFICIENT/);
  assert.equal(room.game!.players[0]!.folded, false);
  addBalance(room, "p0", 100, 1003);
  assert.equal(room.game!.pot, 0);
  act(room, "p0", "PLAY", 1004);
  assert.equal(room.players[0]!.balance, 90);
  assert.equal(room.game!.players[0]!.added, 100);
  assert.deepEqual(
    room.transactions.map((t) => t.kind),
    ["BALANCE_ADD", "CONTRIBUTION"],
  );
});
test("same hand and dealer across payment rounds; new hand rotates dealer", () => {
  const room = started();
  const cards = JSON.stringify(room.game!.players.map((p) => p.cards));
  payRound(room);
  payRound(room);
  assert.equal(room.game!.round, 3);
  assert.equal(room.game!.dealerId, "p0");
  assert.equal(JSON.stringify(room.game!.players.map((p) => p.cards)), cards);
  act(room, "p0", "FOLD", room.game!.startTime + 1);
  act(room, "p1", "FOLD", room.game!.startTime + 1);
  assert.equal(room.game!.result!.winners[0], "p2");
  startHand(room, "p0", 20000);
  assert.equal(room.game!.dealerId, "p1");
});
test("show is optional: all Continue produces a new full payment round", () => {
  const room = started();
  payRound(room);
  payRound(room);
  payRound(room);
  assert.equal(room.game!.phase, "SHOW_CHOICE");
  for (const id of ["p0", "p1", "p2"])
    act(room, id, "CONTINUE", room.game!.startTime + 1);
  assert.equal(room.game!.call, 80);
  assert.equal(room.game!.pot, 360);
  payRound(room);
  assert.equal(room.game!.pot, 600);
  assert.equal(room.players[0]!.balance, 300);
});
test("hidden immutable votes, no self-vote, majority Draw splits equally", () => {
  const room = started();
  voting(room);
  const now = room.game!.startTime + 1;
  assert.throws(() => vote(room, "p0", "p0", now));
  vote(room, "p0", "DRAW", now);
  vote(room, "p1", "DRAW", now);
  assert.throws(() => vote(room, "p0", "p2", now));
  assert.deepEqual(snapshot(room, "p2", now).game!.ballots[0]!.votes, {});
  assert.equal(snapshot(room, "p2", now).game!.ballots[0]!.counts, undefined);
  assert.equal(room.game!.phase, "VOTING");
  expire(room, room.game!.endTime!);
  assert.equal(room.game!.result!.kind, "DRAW");
  assert.deepEqual(
    room.players.map((p) => p.balance),
    [500, 500, 500],
  );
});
test("tie-break retains electorate, restricts candidates and pauses on repeat tie", () => {
  const room = started();
  voting(room);
  let now = room.game!.startTime + 1;
  vote(room, "p0", "p1", now);
  vote(room, "p1", "p0", now);
  vote(room, "p2", "ABSTAIN", now);
  expire(room, room.game!.endTime!);
  assert.equal(room.game!.ballots.length, 2);
  assert.deepEqual(room.game!.ballots[1]!.candidates, ["p0", "p1"]);
  now = room.game!.startTime + 1;
  assert.throws(() => vote(room, "p0", "p2", now));
  vote(room, "p0", "p1", now);
  vote(room, "p1", "p0", now);
  expire(room, room.game!.endTime!);
  assert.equal(room.game!.phase, "PAUSED");
  assert.equal(room.game!.pot, 360);
});
test("all missing votes abstain and preserve pot, never silently draw", () => {
  const room = started();
  voting(room);
  expire(room, room.game!.endTime!);
  assert.equal(room.game!.phase, "PAUSED");
  assert.equal(room.game!.pot, 360);
  assert.equal(room.game!.result, undefined);
});
test("timer folds player, contributions stay, last player wins exactly once", () => {
  const room = started();
  payRound(room);
  expire(room, room.game!.endTime!);
  expire(room, room.game!.endTime!);
  assert.equal(room.game!.phase, "RESULT");
  assert.equal(room.players[2]!.balance, 540);
  assert.equal(room.game!.pot, 0);
  assert.equal(expire(room, 9999999), false);
});
test("remainder is assigned in dealer seat order", () => {
  const room = started(4);
  room.settings.startingCall = 1;
  room.settings.increment = 1;
  room.settings.showAfter = 1;
  // First round was initialized before the settings change; each pays 20.
  payRound(room);
  for (const id of ["p0", "p1", "p2", "p3"])
    act(room, id, "CONTINUE", room.game!.startTime + 1);
  act(room, "p0", "FOLD", room.game!.startTime + 1);
  for (const id of ["p1", "p2", "p3"])
    act(room, id, "PLAY", room.game!.startTime + 1);
  act(room, "p1", "SHOW", room.game!.startTime + 1);
  expire(room, room.game!.endTime!);
  vote(room, "p1", "DRAW", room.game!.startTime + 1);
  vote(room, "p2", "DRAW", room.game!.startTime + 1);
  expire(room, room.game!.endTime!);
  assert.deepEqual(
    room.game!.players.map((p) => p.won),
    [0, 29, 29, 28],
  );
});
for (const count of [3, 5, 6, 10])
  test(`${count} participants preserve total points through a hand`, () => {
    const room = started(count);
    voting(room);
    for (let i = 0; i < count; i++)
      vote(room, `p${i}`, i === 0 ? "p1" : "p0", room.game!.startTime + 1);
    expire(room, room.game!.endTime!);
    assert.equal(
      room.players.reduce((sum, p) => sum + p.balance, 0) + room.game!.pot,
      count * 500,
    );
  });
