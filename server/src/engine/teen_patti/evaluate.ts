import type { Card } from '../cards.js';
import { groups, validateCards, value, type Rank } from '../rankings.js';
/** Approved sequence order: AKQ, A23, KQJ ... 432. Suits never break ties. */
export function evaluateTeenPatti(cards: readonly Card[]): Rank {
  validateCards(cards, 3);
  const ranks=cards.map(value).sort((a,b)=>b-a), g=groups(cards);
  const flush=cards.every(c=>c.suit===cards[0]!.suit);
  const sequence=g.length===3 ? (ranks.join(',')==='14,3,2' ? 13.5 : (ranks[0]! - ranks[2]!) === 2 ? ranks[0]! : 0) : 0;
  if(g[0]![1]===3) return {score:[5,g[0]![0]],label:'Trail / Trio'};
  if(flush && sequence) return {score:[4,sequence],label:'Pure sequence'};
  if(sequence) return {score:[3,sequence],label:'Sequence'};
  if(flush) return {score:[2,...ranks],label:'Color'};
  if(g[0]![1]===2) return {score:[1,g[0]![0],g[1]![0]],label:'Pair'};
  return {score:[0,...ranks],label:'High card'};
}
