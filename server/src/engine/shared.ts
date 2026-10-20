/** Shared, integer-only accounting used by every ruleset. No currency conversion. */
export function points(value: number): number {
  if (!Number.isSafeInteger(value) || value < 0) throw new Error('Invalid virtual points');
  return value;
}
export function transferToPot(balance: number, pot: number, amount: number) {
  points(balance); points(pot); points(amount);
  if (amount > balance) throw new Error('INSUFFICIENT_BALANCE');
  return { balance: balance - amount, pot: points(pot + amount) };
}
/** Caller supplies the ruleset's deterministic clockwise winner order. */
export function splitPoints(total: number, winners: readonly string[]) {
  points(total);
  if (!winners.length || new Set(winners).size !== winners.length) throw new Error('Invalid winners');
  return winners.map((id, i) => ({ id, amount: Math.floor(total / winners.length) + (i < total % winners.length ? 1 : 0) }));
}
export interface GameRules<S, A, V> {
  readonly id: string;
  act(state: S, actor: string, action: A, now: number): void;
  expire(state: S, now: number): boolean;
  view(state: S, viewer: string, now: number): V;
}
/** Shared command boundary: a rejected command cannot partially mutate a hand. */
export class GameEngine<S, A, V> {
  constructor(readonly rules: GameRules<S, A, V>) {}
  command(state: S, actor: string, action: A, now: number): S {
    const next = structuredClone(state);
    this.rules.act(next, actor, action, now);
    return next;
  }
  tick(state: S, now: number): S | null {
    const next = structuredClone(state);
    return this.rules.expire(next, now) ? next : null;
  }
  view(state: S, viewer: string, now: number): V { return this.rules.view(state, viewer, now); }
}
