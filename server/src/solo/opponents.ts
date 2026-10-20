import { randomInt } from 'node:crypto';
import { evaluateTeenPatti } from '../engine/teen_patti/evaluate.js';
import { evaluatePoker } from '../engine/poker/evaluate.js';
import { value } from '../engine/rankings.js';
import type { Action, PlayerView, Profile } from './model.js';
export const profiles:Profile[]=['CAUTIOUS','BALANCED','AGGRESSIVE','UNPREDICTABLE'];
const tuning={CAUTIOUS:{risk:.18,fold:.4},BALANCED:{risk:.4,fold:.23},AGGRESSIVE:{risk:.7,fold:.12},UNPREDICTABLE:{risk:.55,fold:.28}};
export function decisionDelay(profile:Profile,random:()=>number=()=>randomInt(1_000_000)/1_000_000) {
  return Math.floor((profile==='CAUTIOUS'?1100:650)+random()*2400);
}
/** The policy accepts only an eligible player's sanitized view. Never pass a session here. */
export function decide(view:PlayerView,actor:string,profile:Profile,random:()=>number=()=>randomInt(1_000_000)/1_000_000):Action {
  const g=view.game!,me=g.players.find(p=>p.id===actor)!;
  const legal=view.legalActions;
  if(!legal.length)throw new Error('No legal opponent action');
  const has=(type:Action['type'])=>legal.find(a=>a.type===type);
  const t=tuning[profile],r=random();
  if(has('SEE') && (r>.3 || g.round>2))return {type:'SEE'};
  let strength=.38;
  if(me.cards.length===3)strength=(evaluateTeenPatti(me.cards).score[0]!+.5)/6;
  else if(me.cards.length===2){
    if(g.board.length>=3)strength=(evaluatePoker([...me.cards,...g.board]).score[0]!+1)/9;
    else {const a=value(me.cards[0]!),b=value(me.cards[1]!);strength=a===b?.6+a/40:(a+b)/40+(me.cards[0]!.suit===me.cards[1]!.suit?.08:0);}
  }
  const balance=view.players.find(p=>p.id===actor)!.balance;
  const call=has('CALL')??has('PLAY')??has('BLIND');
  const pressure=(call?.cost??0)/Math.max(1,balance);
  if(has('SHOW')&&(g.round>=3||r<t.risk))return {type:'SHOW'};
  if(has('CHECK')&&r>t.risk*strength)return {type:'CHECK'};
  if(has('FOLD')&&!has('CHECK')&&r<t.fold+pressure*.3-strength*.25)return {type:'FOLD'};
  const raise=has('RAISE');
  if(raise&&r<t.risk*strength){const min=raise.min!;return {type:'RAISE',amount:min};}
  if(call)return {type:call.type};
  if(has('CHECK'))return {type:'CHECK'};
  if(has('FOLD'))return {type:'FOLD'};
  return {type:legal[0]!.type};
}
