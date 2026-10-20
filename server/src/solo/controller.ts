import { randomUUID } from 'node:crypto';
import { GameEngine } from '../engine/shared.js';
import { TeenPattiRules } from '../engine/teen_patti/rules.js';
import { PokerRules } from '../engine/poker/rules.js';
import type { Identity } from '../store.js';
import type { SoloSession, SoloSettings, Action, SoloRules } from './model.js';
import { profiles, decide, decisionDelay } from './opponents.js';
import { addPoints, record, requireRule } from './runtime.js';
export const rulesFor=(kind:SoloSettings['kind']):SoloRules=>kind==='POKER'?PokerRules:TeenPattiRules;
const names=['Kavya','Neel','Mira','Dev','Riya','Arjun','Isha','Dhruv','Tara'];
const avatars=['lotus','kite','moon','lion','sun','peacock'];
export class SoloGameController {
  static create(user:Identity,settings:SoloSettings,now:number):SoloSession {
    const s:SoloSession={id:randomUUID(),ownerId:user.id,mode:'SOLO',name:settings.kind==='POKER'?"Texas Hold’em":'Teen Patti',version:0,settings,players:[{...user,seat:0,balance:settings.startingBalance,active:true}],game:null,lastDealerSeat:-1,nextActionAt:null,transactions:[],history:[]};
    for(let i=1;i<settings.playerCount;i++)s.players.push({id:randomUUID(),name:names[i-1]!,avatar:avatars[(i-1)%avatars.length]!,seat:i,balance:settings.startingBalance,active:true,profile:profiles[(i-1)%profiles.length]!});
    for(const p of s.players)record(s,p.id,'INITIAL',p.balance,now);
    rulesFor(settings.kind).start(s,now);this.schedule(s,now);return s;
  }
  static schedule(s:SoloSession,now:number) {
    const g=s.game,p=s.players.find(p=>p.id===g?.pending[0]);
    s.nextActionAt=g?.phase==='DECISION'&&p?.profile?Math.min(now+decisionDelay(p.profile),g.endTime!-100):g?.endTime??null;
  }
  static command(s:SoloSession,actor:string,command:{type:string;amount?:number;action?:Action},now:number) {
    requireRule(s.ownerId===actor,'Private practice session');
    let next=structuredClone(s);const rules=rulesFor(s.settings.kind);
    if(command.type==='NEXT')rules.start(next,now);
    else if(command.type==='BALANCE_ADD')addPoints(next,actor,command.amount!,now);
    else {requireRule(command.type==='ACTION'&&command.action,'Unknown command');next=new GameEngine(rules).command(s,actor,command.action,now);}
    // Out-of-turn See and balance changes must not continually postpone an opponent.
    if(command.type==='NEXT'||next.game?.pending[0]!==s.game?.pending[0]||next.game?.phase!==s.game?.phase)this.schedule(next,now);
    next.version++;return next;
  }
  static tick(s:SoloSession,now:number):SoloSession|null {
    if(s.nextActionAt===null||now<s.nextActionAt)return null;
    const rules=rulesFor(s.settings.kind),engine=new GameEngine(rules);
    let next=engine.tick(s,now);
    if(!next){const actor=s.game!.pending[0]!,p=s.players.find(p=>p.id===actor)!;
      if(!p.profile)return null;
      const decision=decide(engine.view(s,actor,now),actor,p.profile);
      next=engine.command(s,actor,decision,now);
    }
    next.version++;this.schedule(next,now);return next;
  }
  static view(s:SoloSession,viewer:string,now:number){requireRule(viewer===s.ownerId,'Private practice session');return rulesFor(s.settings.kind).view(s,viewer,now);}
}
