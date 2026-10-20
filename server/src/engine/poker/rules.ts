import { evaluatePoker } from './evaluate.js';
import { compare } from '../rankings.js';
import type { SoloRules, SoloSession } from '../../solo/model.js';
import { active, award, begin, clockwise, ensureAction, hand, loneWinner, pay, playerView, record, requireRule, reveal, seat, setTurn } from '../../solo/runtime.js';
function refundUncalled(s:SoloSession,now:number) {
  const g=hand(s),ordered=[...g.players].sort((a,b)=>b.streetPaid-a.streetPaid);
  const p=ordered[0]!, excess=p.streetPaid-(ordered[1]?.streetPaid??0);
  if(excess>0){p.streetPaid-=excess;p.contributed-=excess;g.pot-=excess;seat(s,p.id).balance+=excess;p.allIn=false;record(s,p.id,'REFUND',excess,now);}
}
function settle(s:SoloSession,now:number) {
  const g=hand(s),ranks=new Map(active(s).map(p=>[p.id,evaluatePoker([...p.cards,...g.board])]));
  const levels=[...new Set(g.players.map(p=>p.contributed))].filter(n=>n>0).sort((a,b)=>a-b);
  let previous=0;
  const pots=levels.map(level=>{
    const contributors=g.players.filter(p=>p.contributed>=level);
    const eligible=contributors.filter(p=>!p.folded);
    requireRule(eligible.length,'No eligible side-pot winner; pot preserved');
    const best=eligible.map(p=>ranks.get(p.id)!).sort((a,b)=>compare(b,a))[0]!;
    const amount=(level-previous)*contributors.length;previous=level;
    return {amount,winners:eligible.filter(p=>compare(ranks.get(p.id)!,best)===0).map(p=>p.id)};
  });
  award(s,pots,Object.fromEntries([...ranks].map(([id,rank])=>[id,rank.label])),now);
}
function next(s:SoloSession,now:number) {
  const g=hand(s);
  if(active(s).length===1){refundUncalled(s,now);loneWinner(s,now);return;}
  g.pending=g.pending.filter(id=>{const p=g.players.find(p=>p.id===id)!;return !p.folded&&!p.allIn;});
  const actionable=active(s).filter(p=>!p.allIn);
  if(actionable.length===1 && actionable[0]!.streetPaid>=g.call) g.pending=[];
  if(g.pending.length){setTurn(s,now);return;}
  refundUncalled(s,now);
  if(g.street==='RIVER'){reveal(s,now);return;}
  // Burn cards remain entirely inside the authoritative engine.
  g.deck.shift();
  if(g.street==='PRE_FLOP'){g.board.push(...g.deck.splice(0,3));g.street='FLOP';}
  else {g.board.push(g.deck.shift()!);g.street=g.street==='FLOP'?'TURN':'RIVER';}
  g.round++;g.call=0;g.minRaise=s.settings.bigBlind;
  g.players.forEach(p=>{p.streetPaid=0;p.actedAtBet=null;});
  g.pending=clockwise(s,g.dealerId,active(s).filter(p=>!p.allIn)).map(p=>p.id);
  next(s,now);
}
export const PokerRules: SoloRules = {
  id:'POKER',
  start(s,now){
    begin(s,2,now);const g=hand(s),order=clockwise(s,g.dealerId);
    const small=s.players.length===2?g.dealerId:order[0]!.id;
    const big=s.players.length===2?order[0]!.id:order[1]!.id;
    pay(s,small,Math.min(s.settings.smallBlind,seat(s,small).balance),now);
    pay(s,big,Math.min(s.settings.bigBlind,seat(s,big).balance),now);
    g.players.find(p=>p.id===small)!.lastAction='SMALL BLIND';g.players.find(p=>p.id===big)!.lastAction='BIG BLIND';
    g.call=s.settings.bigBlind;g.pending=clockwise(s,big,active(s).filter(p=>!p.allIn)).map(p=>p.id);next(s,now);
  },
  legal(s,actor){
    const g=hand(s),p=g.players.find(p=>p.id===actor);
    if(g.phase!=='DECISION'||g.pending[0]!==actor||!p||p.folded||p.allIn)return [];
    const balance=seat(s,actor).balance,owed=Math.max(0,g.call-p.streetPaid);
    const actions:ReturnType<SoloRules['legal']>=[{type:'FOLD',label:'Fold'}];
    if(!owed)actions.push({type:'CHECK',label:'Check'});
    else actions.push({type:'CALL',label:balance<=owed?'Call all-in':'Call',cost:Math.min(balance,owed)});
    const reopened=p.actedAtBet===null || g.call-p.actedAtBet>=g.minRaise;
    const canContest=active(s).some(other=>other.id!==actor&&!other.allIn);
    const max=p.streetPaid+balance,min=g.call<s.settings.bigBlind?s.settings.bigBlind:g.call+g.minRaise;
    if(reopened&&canContest&&max>g.call){
      if(max>=min)actions.push({type:'RAISE',label:g.call?'Raise to':'Bet',min,max});
      actions.push({type:'ALL_IN',label:'All-in',cost:balance});
    }
    return actions;
  },
  act(s,actor,action,now){
    const legal=ensureAction(s,actor,action.type,now,PokerRules),g=hand(s),p=g.players.find(p=>p.id===actor)!;
    const before=g.call;
    if(action.type==='FOLD')p.folded=true;
    else if(action.type==='CALL')pay(s,actor,legal.cost!,now);
    else if(action.type==='RAISE'||action.type==='ALL_IN'){
      const target=action.type==='ALL_IN'?p.streetPaid+seat(s,actor).balance:action.amount;
      requireRule(target!==undefined&&Number.isSafeInteger(target)&&target>g.call,'Invalid raise');
      if(action.type==='RAISE')requireRule(target>=legal.min!&&target<=legal.max!,'Raise outside legal range');
      pay(s,actor,target-p.streetPaid,now);
      const increase=target-before;
      if(increase>=g.minRaise)g.minRaise=increase;
      g.call=target;
    }
    p.lastAction=action.type;p.actedAtBet=g.call;
    g.pending.shift();
    if(g.call>before)g.pending=clockwise(s,actor,active(s).filter(p=>!p.allIn&&p.id!==actor&&(p.actedAtBet===null||p.streetPaid<g.call))).map(p=>p.id);
    next(s,now);
  },
  expire(s,now){const g=hand(s);if(g.endTime===null||now<g.endTime)return false;
    if(g.phase==='REVEAL')settle(s,now);else {const actor=g.pending[0]!;const canCheck=PokerRules.legal(s,actor).some(a=>a.type==='CHECK');g.endTime=now+1;PokerRules.act(s,actor,{type:canCheck?'CHECK':'FOLD'},now);}return true;
  },
  view(s,viewer,now){return playerView(s,viewer,now,PokerRules.legal(s,viewer));},
};
