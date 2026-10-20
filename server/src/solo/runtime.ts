import { randomUUID } from 'node:crypto';
import { createDeck, shuffle, deal } from '../engine/cards.js';
import { points, splitPoints, transferToPot } from '../engine/shared.js';
import { MAX_POINTS } from '../engine/game.js';
import type { SoloSession, HandSeat, SoloRules, LegalAction } from './model.js';
export function requireRule(ok:unknown,message:string):asserts ok { if(!ok) throw new Error(message); }
export function seat(s:SoloSession,id:string) { const p=s.players.find(p=>p.id===id); requireRule(p,'Unknown player'); return p; }
export function hand(s:SoloSession) { requireRule(s.game,'No hand'); return s.game; }
export function active(s:SoloSession) { return hand(s).players.filter(p=>!p.folded); }
export function clockwise(s:SoloSession,after:string,eligible:HandSeat[]=hand(s).players):HandSeat[] {
  const all=hand(s).players, index=all.findIndex(p=>p.id===after);
  return [...all.slice(index+1),...all.slice(0,index+1)].filter(p=>eligible.includes(p));
}
export function record(s:SoloSession,id:string,kind:SoloSession['transactions'][number]['kind'],amount:number,now:number) {
  s.transactions.push({id:randomUUID(),playerId:id,kind,amount,balanceAfter:seat(s,id).balance,gameId:s.game?.id??null,at:now});
}
export function addPoints(s:SoloSession,id:string,amount:number,now:number) {
  const p=seat(s,id); points(amount);
  requireRule(amount>0 && p.balance+amount<=MAX_POINTS,'Invalid virtual point addition');
  requireRule(s.settings.kind!=='POKER' || !s.game || s.game.phase==='RESULT','Poker balances can be modified between hands only');
  p.balance+=amount;
  const hp=s.game?.players.find(p=>p.id===id);
  if(hp && s.game?.phase!=='RESULT') hp.added+=amount;
  record(s,id,'BALANCE_ADD',amount,now);
}
export function pay(s:SoloSession,id:string,amount:number,now:number) {
  const p=seat(s,id),g=hand(s),hp=g.players.find(p=>p.id===id)!;
  const update=transferToPot(p.balance,g.pot,amount);
  p.balance=update.balance; g.pot=update.pot; hp.contributed+=amount; hp.streetPaid+=amount;
  hp.allIn=p.balance===0 && s.settings.kind==='POKER';
  if(amount) record(s,id,'CONTRIBUTION',amount,now);
}
export function setTurn(s:SoloSession,now:number) {
  const g=hand(s); g.startTime=now; g.endTime=now+s.settings.decisionSeconds*1000;
}
export function begin(s:SoloSession,count:number,now:number) {
  requireRule(!s.game || s.game.phase==='RESULT','Finish the current hand first');
  requireRule(seat(s,s.ownerId).balance >= (s.settings.kind==='POKER'?1:s.settings.stake),'Your virtual balance is insufficient. Modify virtual balance before starting.');
  // A new practice hand restores exhausted practice seats openly through the audit ledger.
  for(const p of s.players) if(p.id!==s.ownerId && p.balance < (s.settings.kind==='POKER'?s.settings.bigBlind:s.settings.stake)) addPoints(s,p.id,s.settings.startingBalance,now);
  const dealer=s.players.find(p=>p.seat>s.lastDealerSeat)??s.players[0]!;
  s.lastDealerSeat=dealer.seat;
  const shuffled=shuffle(createDeck(['A','2','3','4','5','6','7','8','9','10','J','Q','K'],['S','H','D','C']));
  const dealerIndex=s.players.indexOf(dealer);
  const order=[...s.players.slice(dealerIndex+1),...s.players.slice(0,dealerIndex+1)];
  const dealt=deal(shuffled,order.map(p=>p.id),count);
  s.game={ id:randomUUID(),phase:'DECISION',dealerId:dealer.id,players:s.players.map(p=>({id:p.id,name:p.name,avatar:p.avatar,cards:dealt.hands[p.id]!,folded:false,seen:count===2,blind:count===3,contributed:0,streetPaid:0,startingBalance:p.balance,added:0,won:0,allIn:false,actedAtBet:null})),deck:dealt.remaining,board:[],street:count===2?'PRE_FLOP':'TEEN_PATTI',pending:[],pot:0,call:s.settings.stake,round:1,cardCount:count,startTime:now,endTime:null,minRaise:s.settings.bigBlind,reveal:false,ballots:[] };
}
export function reveal(s:SoloSession,now:number) { const g=hand(s);g.phase='REVEAL';g.reveal=true;g.pending=[];g.startTime=now;g.endTime=now+s.settings.reviewSeconds*1000; }
export function award(s:SoloSession,pots:{amount:number;winners:string[]}[],labels:Record<string,string>,now:number) {
  const g=hand(s); requireRule(!g.result,'Already settled');
  requireRule(pots.reduce((n,p)=>n+p.amount,0)===g.pot,'Settlement must conserve every virtual point');
  for(const pot of pots) {
    const ordered=clockwise(s,g.dealerId).filter(p=>pot.winners.includes(p.id)).map(p=>p.id);
    for(const share of splitPoints(pot.amount,ordered)) {const p=seat(s,share.id);p.balance=points(p.balance+share.amount);g.players.find(p=>p.id===share.id)!.won+=share.amount;record(s,share.id,'PAYOUT',share.amount,now);}
  }
  const winners=[...new Set(pots.flatMap(p=>p.winners))];
  g.result={kind:pots.some(p=>p.winners.length>1)?'DRAW':'WINNER',winners,pot:g.pot,at:now,labels,pots};
  g.pot=0;g.phase='RESULT';g.pending=[];g.endTime=null;s.nextActionAt=null;
  s.history.unshift({id:g.id,date:new Date(now).toISOString(),kind:s.settings.kind,result:g.result,players:g.players.map(p=>({id:p.id,name:p.name,startingBalance:p.startingBalance,added:p.added,contributed:p.contributed,won:p.won,finalBalance:seat(s,p.id).balance}))});
  s.history=s.history.slice(0,50);
}
export function loneWinner(s:SoloSession,now:number) {
  const remaining=active(s);
  requireRule(remaining.length>0,'No eligible players; pot preserved');
  if(remaining.length!==1) return false;
  award(s,[{amount:hand(s).pot,winners:[remaining[0]!.id]}],{},now);return true;
}
/** Explicit allowlist. No deck, other private cards, future board, or opponent policies cross this boundary. */
export function playerView(s:SoloSession,viewer:string,now:number,legal:LegalAction[]=[]){
  seat(s,viewer);
  const g=s.game;
  return {id:s.id,ownerId:s.ownerId,hostId:s.ownerId,mode:s.mode,name:s.name,code:'PRACTICE',version:s.version,settings:s.settings,serverTime:now,
    players:s.players.map(({id,name,avatar,seat,balance,active})=>({id,name,avatar,seat,balance,active})),
    game:g?{id:g.id,phase:g.phase,dealerId:g.dealerId,players:g.players.map(p=>({id:p.id,name:p.name,avatar:p.avatar,folded:p.folded,seen:p.seen,blind:p.blind,contributed:p.contributed,streetPaid:p.streetPaid,startingBalance:p.startingBalance,added:p.added,won:p.won,allIn:p.allIn,lastAction:p.lastAction,cards:((viewer===p.id&&p.seen)||(g.reveal&&!p.folded))?structuredClone(p.cards):[]})),board:structuredClone(g.board),street:g.street,pending:[...g.pending],pot:g.pot,call:g.call,round:g.round,cardCount:g.cardCount,startTime:g.startTime,endTime:g.endTime,minRaise:g.minRaise,ballots:[],result:g.result?structuredClone(g.result):undefined}:null,
    legalActions:legal.map(a=>({...a})),currency:'VIRTUAL_POINTS_ONLY'};
}
export function ensureAction(s:SoloSession,actor:string,type:string,now:number,rules:SoloRules) {
  const g=hand(s);requireRule(g.phase==='DECISION' && g.endTime!==null && now<g.endTime,'Action deadline passed');
  const legal=rules.legal(s,actor).find(a=>a.type===type);requireRule(legal,'Action is not legal now');return legal;
}
