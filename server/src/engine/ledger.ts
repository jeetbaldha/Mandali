export type Contribution = Readonly<{
  playerId: string;
  round: number;
  amount: number;
}>;

function points(value: number) {
  if (!Number.isSafeInteger(value) || value < 0)
    throw new Error("Invalid virtual points");
  return value;
}

export function roundAmount(
  start: number,
  increment: number,
  round: number,
): number {
  points(start);
  points(increment);
  if (!Number.isSafeInteger(round) || round < 1)
    throw new Error("Invalid round");
  return points(start + increment * (round - 1));
}

/** Internal domain primitive: callers must authorize phase, seat and deadline first.
 * Persistence must commit ledger and game state in one database transaction.
 */
export class VirtualLedger {
  private readonly balances = new Map<string, number>();
  private readonly contributions = new Map<string, Contribution>();
  private total = 0;

  constructor(initial: Readonly<Record<string, number>>) {
    for (const [id, balance] of Object.entries(initial)) {
      if (!id) throw new Error("Invalid player");
      this.balances.set(id, points(balance));
    }
  }

  get pot() {
    return this.total;
  }
  balance(playerId: string) {
    const value = this.balances.get(playerId);
    if (value === undefined) throw new Error("Unknown player");
    return value;
  }
  history(): Contribution[] {
    return [...this.contributions.values()].map((c) => ({ ...c }));
  }

  contribute(playerId: string, round: number, amount: number): Contribution {
    points(amount);
    if (!Number.isSafeInteger(round) || round < 1)
      throw new Error("Invalid round");
    const key = JSON.stringify([playerId, round]);
    const previous = this.contributions.get(key);
    if (previous) {
      if (previous.amount !== amount)
        throw new Error("Conflicting duplicate contribution");
      return { ...previous };
    }
    const balance = this.balance(playerId);
    if (balance < amount) throw new Error("Insufficient virtual balance");
    const newPot = points(this.total + amount);
    const contribution = { playerId, round, amount };
    this.balances.set(playerId, balance - amount);
    this.total = newPot;
    this.contributions.set(key, contribution);
    return { ...contribution };
  }
}
