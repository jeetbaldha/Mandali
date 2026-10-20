import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { SoloGameController as Solo, rulesFor } from '../src/solo/controller.js';
import { decide, decisionDelay, profiles } from '../src/solo/opponents.js';
import { GameEngine } from '../src/engine/shared.js';
import { evaluatePoker } from '../src/engine/poker/evaluate.js';
import { evaluateTeenPatti } from '../src/engine/teen_patti/evaluate.js';
import { compare } from '../src/engine/rankings.js';
import type { Card } from '../src/engine/cards.js';
import type { SoloSession, SoloSettings, Action } from '../src/solo/model.js';
import { addPoints } from '../src/solo/runtime.js';
const cards=(text:string):Card[]=>text.split(' ').map(x=>({id:x,rank:x.slice(0,-1),suit:x.slice(-1)}));
const settings=(kind:SoloSettings['kind'],n=4):SoloSettings=>({kind,playerCount:n,startingBalance:1000,stake:20,smallBlind:10,bigBlind:20,decisionSeconds:15,reviewSeconds:15});
const create=(kind:SoloSettings['kind'],n=4)=>Solo.create({id:randomUUID(),name:'You',avatar:'kite'},settings(kind,n),1000);
function act(s:SoloSession,action:Action,actor=s.game!.pending[0]!,now=s.game!.startTime+1){return new GameEngine(rulesFor(s.settings.kind)).command(s,actor,action,now);}
test('Poker evaluates every category, wheel, kicker and best five of seven',()=>{
  const examples=['AS KD 9H 7C 3S','AS AD 9H 7C 3S','AS AD 9H 9C 3S','AS AD AH 7C 3S','AS 2D 3H 4C 5S','AS JS 9S 7S 3S','AS AD AH 7C 7S','AS AD AH AC 3S','9S 10S JS QS KS'];
  examples.forEach((x,i)=>assert.equal(evaluatePoker(cards(x)).score[0],i));
  assert.equal(evaluatePoker(cards('AS 2D 3H 4C 5S')).score[1],5);
  assert.equal(evaluatePoker(cards('AS KS QS JS 10S 2D 2H')).score[0],8);
  assert.equal(compare(evaluatePoker(cards('AS AD KH QC 3D')),evaluatePoker(cards('AH AC KS JD 9D'))),1);
  assert.throws(()=>evaluatePoker(cards('AS AS KH QC 3D')));
});
test('Teen Patti categories and approved sequence order; suits never break ties',()=>{
  ['AS KD 9H','AS AD 9H','AS JS 9S','AS 2D 3H','AS 2S 3S','AS AD AH'].forEach((x,i)=>assert.equal(evaluateTeenPatti(cards(x)).score[0],i));
  const rank=(x:string)=>evaluateTeenPatti(cards(x));
  assert.equal(compare(rank('AS KD QH'),rank('AS 2D 3H')),1);
  assert.equal(compare(rank('AS 2D 3H'),rank('KS QD JH')),1);
  assert.equal(compare(rank('AS KD 9H'),rank('AH KC 9D')),0);
});
for(const kind of ['TEEN_PATTI','POKER'] as const)for(const n of [2,3,4,5,6,10]){
  test(`${kind}: ${n} seats complete real hands, legal opponents and point conservation`,()=>{
    for(let sample=0;sample<5;sample++){
      let s=create(kind,n),count=0;
      const dealt=s.game!.players.flatMap(p=>p.cards).map(c=>c.id);
      assert.equal(new Set(dealt).size,n*(kind==='POKER'?2:3));
      const immutable=JSON.stringify(s.game!.players.map(p=>p.cards));
      while(s.game!.phase!=='RESULT'&&count++<500){
        const rules=rulesFor(kind),g=s.game!;
        if(g.phase==='REVEAL'){rules.expire(s,g.endTime!);continue;}
        const actor=g.pending[0]!,view=rules.view(s,actor,g.startTime+1);
        const choice=decide(view,actor,profiles[count%4]!);
        assert.ok(view.legalActions.some(a=>a.type===choice.type));
        s=act(s,choice,actor);
        assert.equal(JSON.stringify(s.game!.players.map(p=>p.cards)),immutable);
        assert.equal(s.players.reduce((a,p)=>a+p.balance,0)+s.game!.pot,n*1000);
      }
      assert.equal(s.game!.phase,'RESULT',`Hand failed to terminate: ${kind}`);
      assert.ok(s.game!.result!.winners.length);
      assert.equal(s.game!.pot,0);
    }
  });
}
test('Opponent views do not expose unseen cards, deck, profiles or future board',()=>{
  for(const kind of ['TEEN_PATTI','POKER'] as const){
    const s=create(kind),rules=rulesFor(kind),actor=s.game!.pending[0]!;
    const view=rules.view(s,actor,1001);
    assert.equal('deck' in view.game!,false);
    assert.ok(view.game!.players.filter(p=>p.id!==actor).every(p=>p.cards.length===0));
    if(kind==='TEEN_PATTI')assert.equal(view.game!.players.find(p=>p.id===actor)!.cards.length,0);
    const changed=structuredClone(s);
    changed.game!.deck.reverse();
    changed.game!.players.filter(p=>p.id!==actor).forEach(p=>p.cards.reverse());
    assert.deepEqual(rules.view(changed,actor,1001),view);
    assert.deepEqual(decide(rules.view(changed,actor,1001),actor,'BALANCED',()=>.42),decide(view,actor,'BALANCED',()=>.42));
    assert.equal('profile' in view.players[1]!,false);
  }
});
test('Rejected actions are atomic; private session cannot be controlled or viewed by another identity',()=>{
  const s=create('POKER'),before=JSON.stringify(s);
  assert.throws(()=>act(s,{type:'RAISE',amount:1}));assert.equal(JSON.stringify(s),before);
  assert.throws(()=>Solo.command(s,'intruder',{type:'NEXT'},1001));
  assert.throws(()=>Solo.view(s,'intruder',1001));
  assert.throws(()=>act(s,{type:'CALL'},s.game!.players.find(p=>p.id!==s.game!.pending[0])!.id));
});
test('Teen Patti full payments, seen multiplier, balance addition and Show restrictions',()=>{
  let s=create('TEEN_PATTI',3),actor=s.game!.pending[0]!;
  const rules=rulesFor('TEEN_PATTI');
  const pot=s.game!.pot;
  s=act(s,{type:'SEE'},actor);assert.equal(s.game!.pot,pot);
  assert.equal(rules.legal(s,actor).find(a=>a.type==='PLAY')!.cost,40);
  assert.ok(!rules.legal(s,actor).some(a=>a.type==='SHOW'));
  s=act(s,{type:'PLAY'},actor);assert.equal(s.game!.pot,pot+40);
  actor=s.game!.pending[0]!;s.players.find(p=>p.id===actor)!.balance=0;
  assert.ok(!rules.legal(s,actor).some(a=>a.type==='BLIND'));
  assert.equal(s.game!.players.find(p=>p.id===actor)!.folded,false);
  const before=s.game!.pot;addPoints(s,actor,200,1002);assert.equal(s.game!.pot,before);
  s=act(s,{type:'BLIND'},actor);assert.equal(s.game!.players.find(p=>p.id===actor)!.contributed,40);
  assert.ok(s.transactions.some(t=>t.kind==='BALANCE_ADD'));
});
test('Teen Patti Show reveals for inspection; equal hands favor non-requester',()=>{
  let s=create('TEEN_PATTI',2);const actor=s.game!.pending[0]!,other=s.game!.players.find(p=>p.id!==actor)!;
  s.game!.players.find(p=>p.id===actor)!.cards=cards('AS KD 9H');other.cards=cards('AH KC 9D');
  s=act(s,{type:'SHOW'});assert.equal(s.game!.phase,'REVEAL');assert.equal(s.game!.result,undefined);
  assert.ok(rulesFor('TEEN_PATTI').view(s,s.ownerId,1002).game!.players.every(p=>p.cards.length===3));
  rulesFor('TEEN_PATTI').expire(s,s.game!.endTime!);
  assert.deepEqual(s.game!.result!.winners,[other.id]);
});
test('Poker heads-up blinds and street order; adding balance only between hands',()=>{
  let s=create('POKER',2);const dealer=s.game!.dealerId;
  assert.equal(s.game!.pending[0],dealer);
  assert.equal(s.game!.players.find(p=>p.id===dealer)!.streetPaid,10);
  assert.throws(()=>addPoints(s,s.ownerId,100,1002),/between hands/);
  s=act(s,{type:'CALL'});s=act(s,{type:'CHECK'});
  assert.equal(s.game!.street,'FLOP');assert.equal(s.game!.board.length,3);assert.notEqual(s.game!.pending[0],dealer);
  s=act(s,{type:'FOLD'});const pot=s.game!.result!.pot;addPoints(s,s.ownerId,100,1003);assert.equal(s.game!.result!.pot,pot);
  const next=Solo.command(s,s.ownerId,{type:'NEXT'},2000);assert.notEqual(next.game!.dealerId,dealer);
});
test('Poker short all-in does not reopen raising for a player who already acted',()=>{
  let s=create('POKER',3);
  s=act(s,{type:'RAISE',amount:100});const raiser=s.game!.players.find(p=>p.actedAtBet===100)!;
  const next=s.game!.pending[0]!;s.players.find(p=>p.id===next)!.balance=120-s.game!.players.find(p=>p.id===next)!.streetPaid;
  s=act(s,{type:'ALL_IN'});assert.equal(s.game!.call,120);assert.equal(s.game!.minRaise,80);
  s=act(s,{type:'CALL'});assert.equal(s.game!.pending[0],raiser.id);
  assert.ok(!rulesFor('POKER').legal(s,raiser.id).some(a=>a.type==='RAISE'||a.type==='ALL_IN'));
});
test('Poker side pots award only eligible hands and preserve points',()=>{
  const s=create('POKER',3),g=s.game!,[a,b,c]=g.players;
  g.board=cards('2S 3D 7H 9C JS');g.phase='REVEAL';g.reveal=true;g.endTime=2000;
  a!.cards=cards('AS AD');b!.cards=cards('KS KD');c!.cards=cards('QS QD');
  [100,200,300].forEach((n,i)=>{g.players[i]!.contributed=n;g.players[i]!.streetPaid=0;s.players[i]!.balance=1000-n;});g.pot=600;
  rulesFor('POKER').expire(s,2000);
  assert.equal(a!.won,300);assert.equal(b!.won,200);assert.equal(c!.won,100);
  assert.equal(s.players.reduce((n,p)=>n+p.balance,0),3000);
});
test('Poker board tie splits deterministically; folded cards are never revealed',()=>{
  const s=create('POKER',3),g=s.game!;
  g.board=cards('AS KS QS JS 10S');g.phase='REVEAL';g.reveal=true;g.endTime=2000;
  g.players.forEach((p,i)=>{p.cards=cards(i===0?'2D 3D':i===1?'4D 5D':'6D 7D');p.contributed=21;p.streetPaid=0;s.players[i]!.balance=979;});
  g.players[2]!.folded=true;g.pot=63;
  rulesFor('POKER').expire(s,2000);
  assert.equal(g.result!.kind,'DRAW');assert.equal(g.players[1]!.won,32);assert.equal(g.players[0]!.won,31);assert.equal(g.players[2]!.won,0);
  assert.equal(Solo.view(s,s.ownerId,2001).game!.players[2]!.cards.length,0);
});
test('Opponent delays vary within a short bounded interval and timers survive serialization',()=>{
  assert.notEqual(decisionDelay('CAUTIOUS',()=>0),decisionDelay('AGGRESSIVE',()=>1));
  for(const p of profiles){assert.ok(decisionDelay(p,()=>0)>=600);assert.ok(decisionDelay(p,()=>1)<=3500);}
  const s=create('TEEN_PATTI',2),restored=JSON.parse(JSON.stringify(s)) as SoloSession;
  assert.ok(Solo.tick(restored,restored.nextActionAt!));
});
