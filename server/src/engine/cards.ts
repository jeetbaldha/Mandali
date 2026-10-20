import { randomInt } from "node:crypto";

export type Card = Readonly<{ id: string; rank: string; suit: string }>;

/** Deck composition is supplied by the approved rules, never by a client. */
export function createDeck(
  ranks: readonly string[],
  suits: readonly string[],
): Card[] {
  if (
    !ranks.length ||
    !suits.length ||
    new Set(ranks).size !== ranks.length ||
    new Set(suits).size !== suits.length ||
    [...ranks, ...suits].some((v) => !v)
  ) {
    throw new Error("Invalid deck specification");
  }
  return suits.flatMap((suit) =>
    ranks.map((rank) => ({
      id: JSON.stringify([suit, rank]),
      rank,
      suit,
    })),
  );
}

export function shuffle(deck: readonly Card[]): Card[] {
  const shuffled = [...deck];
  for (let i = shuffled.length - 1; i > 0; i--) {
    const j = randomInt(i + 1);
    [shuffled[i], shuffled[j]] = [shuffled[j]!, shuffled[i]!];
  }
  return shuffled;
}

export function deal(
  deck: readonly Card[],
  seats: readonly string[],
  count: number,
) {
  if (
    !Number.isSafeInteger(count) ||
    count < 1 ||
    !seats.length ||
    new Set(seats).size !== seats.length ||
    seats.some((s) => !s) ||
    seats.length * count > deck.length ||
    new Set(deck.map((c) => c.id)).size !== deck.length
  ) {
    throw new Error("Invalid deal");
  }
  const hands: Record<string, Card[]> = Object.create(null);
  seats.forEach((id) => {
    hands[id] = [];
  });
  let cursor = 0;
  for (let n = 0; n < count; n++) {
    for (const id of seats) hands[id]!.push(deck[cursor++]!);
  }
  return { hands, remaining: deck.slice(cursor) };
}
