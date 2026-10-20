import { test } from "node:test";
import assert from "node:assert/strict";
import { createDeck, shuffle, deal } from "../src/engine/cards.js";
import { VirtualLedger, roundAmount } from "../src/engine/ledger.js";
import { phaseWindow, assertBeforeDeadline } from "../src/engine/timer.js";

test("new round payments accumulate: 20 + 40 + 60 + 80 = 200", () => {
  const ledger = new VirtualLedger({ jeet: 500 });
  for (let round = 1; round <= 4; round++)
    ledger.contribute("jeet", round, roundAmount(20, 20, round));
  assert.equal(ledger.pot, 200);
  assert.equal(ledger.balance("jeet"), 300);
});

test("folding adds nothing and leaves previous contributions in the pot", () => {
  const ledger = new VirtualLedger({ a: 500, b: 500, c: 500, d: 500, e: 500 });
  ["a", "b", "c", "d", "e"].forEach((id) => ledger.contribute(id, 1, 20));
  ["a", "b", "c", "d"].forEach((id) => ledger.contribute(id, 2, 40));
  ["a", "b", "c"].forEach((id) => ledger.contribute(id, 3, 60));
  assert.equal(ledger.pot, 440);
  assert.equal(ledger.balance("e"), 480);
  assert.equal(ledger.balance("a"), 380);
});

test("duplicate payments are idempotent; conflicting retries are rejected", () => {
  const ledger = new VirtualLedger({ a: 500 });
  ledger.contribute("a", 1, 20);
  ledger.contribute("a", 1, 20);
  assert.equal(ledger.pot, 20);
  assert.throws(() => ledger.contribute("a", 1, 40));
  const history = ledger.history();
  history.pop();
  assert.equal(ledger.history().length, 1);
});

test("invalid points and overspending leave ledger unchanged", () => {
  const ledger = new VirtualLedger({ a: 20 });
  for (const amount of [
    -1,
    0.5,
    NaN,
    Infinity,
    21,
    Number.MAX_SAFE_INTEGER + 1,
  ]) {
    assert.throws(() => ledger.contribute("a", 1, amount));
  }
  assert.throws(() => ledger.contribute("unknown", 1, 10));
  assert.equal(ledger.pot, 0);
  assert.equal(ledger.balance("a"), 20);
});

// A standard deck is a test fixture, not an activated game-rule default.
for (const size of [2, 3, 5, 6, 10]) {
  test(`secure shuffle and unique dealing for ${size} seats`, () => {
    const deck = createDeck(
      Array.from({ length: 13 }, (_, i) => String(i + 1)),
      ["S", "H", "D", "C"],
    );
    const original = JSON.stringify(deck);
    const mixed = shuffle(deck);
    const result = deal(
      mixed,
      Array.from({ length: size }, (_, i) => `p${i}`),
      3,
    );
    const cards = Object.values(result.hands).flat();
    assert.equal(new Set(cards.map((c) => c.id)).size, size * 3);
    assert.equal(result.remaining.length, 52 - size * 3);
    assert.equal(JSON.stringify(deck), original);
    assert.deepEqual(
      new Set(mixed.map((c) => c.id)),
      new Set(deck.map((c) => c.id)),
    );
  });
}

test("invalid and oversized deals fail", () => {
  const deck = createDeck(["A"], ["S"]);
  assert.throws(() => deal(deck, ["a", "b"], 1));
  assert.throws(() => deal(deck, ["a", "a"], 1));
  assert.throws(() => createDeck(["A", "A"], ["S"]));
});

test("deadline is exclusive and relies on server time", () => {
  const window = phaseWindow("PLAYER_DECISION", 1000, 15000);
  assertBeforeDeadline(window, 15999);
  assert.throws(() => assertBeforeDeadline(window, 16000));
  assert.throws(() => assertBeforeDeadline(window, 999));
});
