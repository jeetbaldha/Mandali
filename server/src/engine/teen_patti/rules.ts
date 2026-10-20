import { compare } from '../rankings.js';
import { evaluateTeenPatti } from './evaluate.js';
import type { SoloRules, SoloSession } from '../../solo/model.js';
import { active, award, begin, clockwise, ensureAction, hand, loneWinner, pay, playerView, requireRule, reveal, seat, setTurn } from '../../solo/runtime.js';
function settle(s:SoloSession,now:number) {
  const g=hand(s),players=active(s), ranks=players.map(p=>({id:p.id,rank:evaluateTeenPatti(p.cards)}));
  ranks.sort((a,b)=>compare(b.rank,a.rank));
  let winners=ranks.filter(p=>compare(p.rank,ranks[0]!.rank)===0).map(p=>p.id);
  if(winners.length>1 && g.showRequester) winners=winners.filter(id=>id!==g.showRequester);
  award(s,[{amount:g.pot,winners}],Object.fromEntries(ranks.map(p=>[p.id,p.rank.label])),now);
}
export const TeenPattiRules: SoloRules = {
  id:'TEEN_PATTI',
  start(s,now){begin(s,3,now);for(const p of s.players)pay(s,p.id,s.settings.stake,now);hand(s).pending=clockwise(s,hand(s).dealerId).map(p=>p.id);setTurn(s,now);},
  legal(s,actor){
    const g=hand(s),p=g.players.find(p=>p.id===actor);if(!p ||p.folded||g.phase!=='DECISION')return [];
    const actions:ReturnType<SoloRules['legal']>=[];
    if(!p.seen)actions.push({type:'SEE',label:'See cards'});
    if(g.pending[0]!==actor)return actions;
    const multiplier=p.seen?2:1,cost=g.call*multiplier;
    actions.push({type:'FOLD',label:"Don't play"});
    if(seat(s,actor).balance>=cost) actions.push({type:p.seen?'PLAY':'BLIND',label:p.seen?'Play':'Blind',cost});
    const max=Math.min(g.call*2*multiplier,seat(s,actor).balance);
    if(max>=cost+multiplier)actions.push({type:'RAISE',label:'Raise stake',min:cost+multiplier,max});
    if(active(s).length===2 && (!p.seen||active(s).every(p=>p.seen)) && seat(s,actor).balance>=g.call*2)actions.push({type:'SHOW',label:'Show',cost:g.call*2});
    return actions;
  },
  act(s,actor,action,now){
    const legal=ensureAction(s,actor,action.type,now,TeenPattiRules),g=hand(s),p=g.players.find(p=>p.id===actor)!;
    if(action.type==='SEE'){p.seen=true;p.blind=false;return;}
    if(action.type==='FOLD')p.folded=true;
    else if(action.type==='RAISE'){
      const n=action.amount;const multiplier=p.seen?2:1;
      requireRule(n!==undefined&&Number.isSafeInteger(n)&&n>=legal.min!&&n<=legal.max!&&n%multiplier===0,'Enter a valid stake (seen stakes use even points)');
      pay(s,actor,n,now);g.call=n/multiplier;
    }else pay(s,actor,legal.cost!,now);
    p.lastAction=action.type;
    if(loneWinner(s,now))return;
    if(action.type==='SHOW'){g.showRequester=actor;reveal(s,now);return;}
    g.pending.shift();g.pending=g.pending.filter(id=>!g.players.find(p=>p.id===id)!.folded);
    if(!g.pending.length){g.round++;g.pending=clockwise(s,g.dealerId,active(s)).map(p=>p.id);}
    setTurn(s,now);
  },
  expire(s,now){const g=hand(s);if(g.endTime===null||now<g.endTime)return false;
    if(g.phase==='REVEAL')settle(s,now);else {const actor=g.pending[0]!;g.endTime=now+1;TeenPattiRules.act(s,actor,{type:'FOLD'},now);}return true;
  },
  view(s,viewer,now){return playerView(s,viewer,now,TeenPattiRules.legal(s,viewer));},
};
