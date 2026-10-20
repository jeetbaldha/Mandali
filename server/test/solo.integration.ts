import {test} from 'node:test';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {readFile,readdir} from 'node:fs/promises';
import {config} from 'dotenv';
import {Store} from '../src/store.js';
import {createApp} from '../src/app.js';
import {io, type Socket} from 'socket.io-client';
config({path:'../.env',quiet:true});
test('Private practice: real HTTP, persistence, duplicate commands, authorization, restart and history',{timeout:45000},async()=>{
  const base=process.env.DATABASE_URL!;assert.ok(base);
  const admin=new Store(base),schema=`test_solo_${randomUUID().replaceAll('-','')}`;
  await admin.pool.query(`CREATE SCHEMA ${schema}`);
  const url=new URL(base);url.searchParams.set('options',`-c search_path=${schema}`);
  const store=new Store(url.toString());let service:ReturnType<typeof createApp>|undefined;let socket:Socket|undefined;
  try{
    const directory=new URL('../../database/migrations/',import.meta.url);
    for(const file of (await readdir(directory)).filter(f=>f.endsWith('.sql')).sort())await store.pool.query(await readFile(new URL(file,directory),'utf8'));
    service=createApp(store);await new Promise<void>(resolve=>service!.server.listen(0,'127.0.0.1',resolve));
    let address=`http://127.0.0.1:${(service.server.address() as any).port}`;
    const user=await store.guest('Practice tester','kite'),other=await store.guest('Other','moon');
    async function request(path:string,body?:unknown,token=user.token){
      const response=await fetch(`${address}${path}`,{method:body?'POST':'GET',headers:{'content-type':'application/json',authorization:`Bearer ${token}`},body:body?JSON.stringify(body):undefined});
      return {status:response.status,data:await response.json() as any};
    }
    socket=io(address,{transports:['websocket'],auth:{token:user.token},reconnection:false});
    await new Promise<void>((resolve,reject)=>{socket!.once('connect',resolve);socket!.once('connect_error',reject);});
    const start={commandId:randomUUID(),settings:{kind:'POKER',playerCount:2,startingBalance:1000,smallBlind:10,bigBlind:20}};
    const created=await request('/practice/start',start);assert.equal(created.status,200);let view=created.data;
    assert.equal(view.mode,'SOLO');assert.equal(view.game.pending[0],user.user.id);
    assert.equal(view.game.deck,undefined);assert.equal(view.game.players[1].cards.length,0);
    assert.equal((await request('/practice/start',start)).data.id,view.id);
    assert.equal((await request('/rooms')).data.length,0);
    assert.equal((await request('/practice',undefined,other.token)).data,null);
    const fold={commandId:randomUUID(),sessionId:view.id,version:view.version,command:{type:'ACTION',action:{type:'FOLD'}}};
    assert.equal((await request('/practice/command',fold,other.token)).status,400);
    const result=await request('/practice/command',fold);assert.equal(result.status,200);assert.equal(result.data.game.phase,'RESULT');
    assert.deepEqual((await request('/practice/command',fold)).data.game.result,result.data.game.result);
    assert.equal((await request('/practice/command',{...fold,command:{type:'BALANCE_ADD',amount:50}})).status,400);
    const balance={commandId:randomUUID(),sessionId:view.id,version:result.data.version,command:{type:'BALANCE_ADD',amount:500}};
    const added=await request('/practice/command',balance);assert.equal(added.status,200);
    assert.equal(added.data.players[0].balance,result.data.players[0].balance+500);
    assert.equal((await request('/practice/command',balance)).data.players[0].balance,added.data.players[0].balance);
    assert.equal((await request('/practice/history')).data.length,1);
    assert.equal((await request('/practice/transactions')).data.filter((t:any)=>t.kind==='BALANCE_ADD').length,1);
    socket.disconnect();await service.close();service=createApp(store);await new Promise<void>(resolve=>service!.server.listen(0,'127.0.0.1',resolve));address=`http://127.0.0.1:${(service.server.address() as any).port}`;
    assert.equal((await request('/practice')).data.players[0].balance,added.data.players[0].balance);
    const next=await request('/practice/command',{commandId:randomUUID(),sessionId:view.id,version:added.data.version,command:{type:'NEXT'}});
    assert.equal(next.status,200);assert.notEqual(next.data.game.dealerId,view.game.dealerId);
    const state=(await store.pool.query('SELECT state FROM solo_sessions WHERE owner_id=$1',[user.user.id])).rows[0].state;
    state.nextActionAt=Date.now()-1;await store.pool.query('UPDATE solo_sessions SET state=$2,next_action_at=$3 WHERE owner_id=$1',[user.user.id,state,state.nextActionAt]);
    await new Promise(resolve=>setTimeout(resolve,650));
    const advanced=(await request('/practice')).data;assert.ok(advanced.version>next.data.version);
    assert.equal((await request('/practice/command',{commandId:randomUUID(),sessionId:view.id,version:0,command:{type:'NEXT'}})).status,400);
  }finally{socket?.disconnect();await service?.close();await store.pool.end();await admin.pool.query(`DROP SCHEMA ${schema} CASCADE`);await admin.pool.end();}
});
