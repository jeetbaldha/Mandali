import type { Card } from '../cards.js';
import { compare, groups, validateCards, value, type Rank } from '../rankings.js';
function five(cards: readonly Card[]): Rank {
  const ranks = cards.map(value).sort((a,b) => b-a);
  const g = groups(cards);
  const flush = cards.every(c => c.suit === cards[0]!.suit);
  const unique = [...new Set(ranks)];
  const straight = unique.length === 5 ? (unique[0]! - unique[4]! === 4 ? unique[0]! : unique.join(',') === '14,5,4,3,2' ? 5 : 0) : 0;
  if (flush && straight) return {score:[8,straight],label:'Straight flush'};
  if (g[0]![1] === 4) return {score:[7,g[0]![0],g[1]![0]],label:'Four of a kind'};
  if (g[0]![1] === 3 && g[1]![1] === 2) return {score:[6,g[0]![0],g[1]![0]],label:'Full house'};
  if (flush) return {score:[5,...ranks],label:'Flush'};
  if (straight) return {score:[4,straight],label:'Straight'};
  if (g[0]![1] === 3) return {score:[3,...g.map(x=>x[0])],label:'Three of a kind'};
  if (g[0]![1] === 2 && g[1]![1] === 2) return {score:[2,...g.map(x=>x[0])],label:'Two pair'};
  if (g[0]![1] === 2) return {score:[1,...g.map(x=>x[0])],label:'Pair'};
  return {score:[0,...ranks],label:'High card'};
}
export function evaluatePoker(cards: readonly Card[]): Rank {
  validateCards(cards, 5, 7);
  let best: Rank | undefined;
  for(let a=0;a<cards.length-4;a++) for(let b=a+1;b<cards.length-3;b++) for(let c=b+1;c<cards.length-2;c++) for(let d=c+1;d<cards.length-1;d++) for(let e=d+1;e<cards.length;e++) {
    const rank=five([cards[a]!,cards[b]!,cards[c]!,cards[d]!,cards[e]!]);
    if(!best || compare(rank,best)>0) best=rank;
  }
  return best!;
}
