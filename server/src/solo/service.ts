import type { Express } from 'express';
import type { Server } from 'socket.io';
import { z } from 'zod';
import { hash, type Store } from '../store.js';
import type { SoloSession, SoloSettings } from './model.js';
import { SoloGameController as Solo } from './controller.js';
import { requireRule } from './runtime.js';
const settings=z.object({kind:z.enum(['TEEN_PATTI','POKER']),playerCount:z.number().int().min(2).max(10),startingBalance:z.number().int().min(1).max(1_000_000_000),stake:z.number().int().min(1).max(100000).default(20),smallBlind:z.number().int().min(1).max(100000).default(10),bigBlind:z.number().int().min(2).max(200000).default(20),decisionSeconds:z.union([z.literal(10),z.literal(15)]).default(15),reviewSeconds:z.number().int().min(15).max(20).default(15)}).strict().refine(s=>s.kind==='POKER'?s.bigBlind>=s.smallBlind*2&&s.startingBalance>=s.bigBlind:s.startingBalance>=s.stake,'Starting balance and stakes are inconsistent');
const action=z.object({type:z.enum(['FOLD','CHECK','CALL','RAISE','ALL_IN','SEE','BLIND','PLAY','SHOW']),amount:z.number().int().min(1).max(1_000_000_000).optional()}).strict();
const command=z.discriminatedUnion('type',[
  z.object({type:z.literal('NEXT')}).strict(),
  z.object({type:z.literal('BALANCE_ADD'),amount:z.number().int().min(1).max(1_000_000_000)}).strict(),
  z.object({type:z.literal('ACTION'),action}).strict(),
]);
const envelope=z.object({commandId:z.string().uuid(),sessionId:z.string().uuid(),version:z.number().int().min(0),command}).strict();
export function installSolo(app:Express,io:Server,store:Store){
  async function load(owner:string):Promise<SoloSession|null>{return (await store.pool.query('SELECT state FROM solo_sessions WHERE owner_id=$1',[owner])).rows[0]?.state??null;}
  async function change(owner:string,id:string|null,fingerprint:string|null,fn:(s:SoloSession|null)=>SoloSession|null){
    const db=await store.pool.connect();
    try{
      await db.query('BEGIN');await db.query('SELECT pg_advisory_xact_lock(hashtext($1))',[`solo:${owner}`]);
      const current:SoloSession|null=(await db.query('SELECT state FROM solo_sessions WHERE owner_id=$1 FOR UPDATE',[owner])).rows[0]?.state??null;
      if(id){const previous=(await db.query('SELECT request_hash FROM solo_commands WHERE owner_id=$1 AND command_id=$2',[owner,id])).rows[0];
        if(previous){requireRule(previous.request_hash===fingerprint,'Conflicting command ID');await db.query('COMMIT');return current;}}
      const next=fn(current);
      if(next){
        for(const tx of next.transactions)await db.query('INSERT INTO solo_transactions VALUES($1,$2,$3,$4,$5,$6,$7,$8,to_timestamp($9/1000.0)) ON CONFLICT DO NOTHING',[tx.id,owner,next.id,tx.playerId,tx.kind,tx.amount,tx.balanceAfter,tx.gameId,tx.at]);
        next.transactions=[];
        for(const result of next.history)await db.query('INSERT INTO solo_results(game_id,owner_id,result) VALUES($1,$2,$3) ON CONFLICT DO NOTHING',[result.id,owner,result]);
        await db.query('INSERT INTO solo_sessions(owner_id,id,state,next_action_at) VALUES($1,$2,$3,$4) ON CONFLICT(owner_id) DO UPDATE SET id=excluded.id,state=excluded.state,next_action_at=excluded.next_action_at,updated_at=now()',[owner,next.id,next,next.nextActionAt]);
      }
      if(id)await db.query('INSERT INTO solo_commands VALUES($1,$2,$3)',[owner,id,fingerprint]);
      await db.query('COMMIT');return next??current;
    }catch(e){await db.query('ROLLBACK');throw e;}finally{db.release();}
  }
  function publish(s:SoloSession){io.to(`practice:${s.ownerId}`).emit('practice:state',Solo.view(s,s.ownerId,Date.now()));}
  app.get('/practice',async(_req,res)=>{try{const s=await load(res.locals.user.id);res.json(s?Solo.view(s,res.locals.user.id,Date.now()):null);}catch{res.status(503).json({error:'Practice is temporarily unavailable'});}});
  app.get('/practice/history',async(_req,res)=>{try{res.json((await store.pool.query('SELECT result FROM solo_results WHERE owner_id=$1 ORDER BY created_at DESC LIMIT 50',[res.locals.user.id])).rows.map(r=>r.result));}catch{res.status(503).json({error:'History unavailable'});}});
  app.get('/practice/transactions',async(_req,res)=>{try{res.json((await store.pool.query('SELECT kind,amount,balance_after,created_at,game_id,player_id FROM solo_transactions WHERE owner_id=$1 ORDER BY created_at DESC LIMIT 100',[res.locals.user.id])).rows);}catch{res.status(503).json({error:'History unavailable'});}});
  app.post('/practice/start',async(req,res)=>{
    try{const input=z.object({commandId:z.string().uuid(),settings}).strict().parse(req.body),user=res.locals.user;
      const s=await change(user.id,input.commandId,hash(JSON.stringify(input)),current=>{requireRule(!current?.game||current.game.phase==='RESULT','Resume your unfinished practice hand first');return Solo.create(user,input.settings as SoloSettings,Date.now());});
      publish(s!);res.json(Solo.view(s!,user.id,Date.now()));
    }catch(e){res.status(400).json({error:e instanceof z.ZodError?'Check the practice settings':e instanceof Error?e.message:'Unable to start practice'});}
  });
  app.post('/practice/command',async(req,res)=>{
    try{const input=envelope.parse(req.body),owner=res.locals.user.id;
      const s=await change(owner,input.commandId,hash(JSON.stringify(input)),current=>{requireRule(current&&current.id===input.sessionId,'Session not found');requireRule(current.version===input.version,'STALE_STATE: refresh and try again');return Solo.command(current,owner,input.command,Date.now());});
      publish(s!);res.json(Solo.view(s!,owner,Date.now()));
    }catch(e){res.status(400).json({error:e instanceof z.ZodError?'Invalid practice action':e instanceof Error?e.message:'Practice action failed'});}
  });
  let ticking=false;
  const timer=setInterval(async()=>{
    if(ticking)return;ticking=true;
    try{const rows=await store.pool.query('SELECT owner_id FROM solo_sessions WHERE next_action_at<=$1 LIMIT 100',[Date.now()]);
      for(const {owner_id} of rows.rows){const s=await change(owner_id,null,null,current=>current?Solo.tick(current,Date.now()):null);if(s)publish(s);}
    }catch(e){console.error('Practice timer:',e instanceof Error?e.message:'unavailable');}finally{ticking=false;}
  },250);
  return ()=>clearInterval(timer);
}
