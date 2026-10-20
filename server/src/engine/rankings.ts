import type { Card } from './cards.js';
export type Rank = { score: number[]; label: string };
export function value(card: Card): number { return '23456789TJQKA'.indexOf(card.rank === '10' ? 'T' : card.rank) + 2; }
export function compare(a: Rank, b: Rank): number {
  for (let i = 0; i < Math.max(a.score.length, b.score.length); i++) {
    const delta = (a.score[i] ?? 0) - (b.score[i] ?? 0);
    if (delta) return Math.sign(delta);
  }
  return 0;
}
export function validateCards(cards: readonly Card[], min: number, max = min) {
  if (cards.length < min || cards.length > max || new Set(cards.map(c => `${c.rank}:${c.suit}`)).size !== cards.length ||
      cards.some(c => !['S','H','D','C'].includes(c.suit) || !['2','3','4','5','6','7','8','9','10','J','Q','K','A'].includes(c.rank))) throw new Error('Invalid cards');
}
export function groups(cards: readonly Card[]) {
  const counts = new Map<number, number>();
  cards.forEach(c => counts.set(value(c), (counts.get(value(c)) ?? 0) + 1));
  return [...counts].sort((a, b) => b[1] - a[1] || b[0] - a[0]);
}
