import type { Card } from '../engine/cards.js';
import type { GameRules } from '../engine/shared.js';
export type GameKind = 'TEEN_PATTI' | 'POKER';
export type Profile = 'CAUTIOUS' | 'BALANCED' | 'AGGRESSIVE' | 'UNPREDICTABLE';
export type SoloSettings = { kind: GameKind; playerCount: number; startingBalance: number; stake: number; smallBlind: number; bigBlind: number; decisionSeconds: number; reviewSeconds: number };
export type Seat = { id:string; name:string; avatar:string; seat:number; balance:number; active:boolean; profile?:Profile };
export type HandSeat = { id:string; name:string; avatar:string; cards:Card[]; folded:boolean; seen:boolean; blind:boolean; contributed:number; streetPaid:number; startingBalance:number; added:number; won:number; allIn:boolean; lastAction?:string; actedAtBet:number|null };
export type Action = { type:'FOLD'|'CHECK'|'CALL'|'RAISE'|'ALL_IN'|'SEE'|'BLIND'|'PLAY'|'SHOW'; amount?:number };
export type LegalAction = { type:Action['type']; label:string; cost?:number; min?:number; max?:number };
export type SoloHand = { id:string; phase:'DECISION'|'REVEAL'|'RESULT'; dealerId:string; players:HandSeat[]; deck:Card[]; board:Card[]; street:'PRE_FLOP'|'FLOP'|'TURN'|'RIVER'|'TEEN_PATTI'; pending:string[]; pot:number; call:number; round:number; cardCount:number; startTime:number; endTime:number|null; minRaise:number; reveal:boolean; showRequester?:string; ballots:never[]; result?:{kind:'WINNER'|'DRAW'; winners:string[]; pot:number; at:number; labels:Record<string,string>; pots:{amount:number; winners:string[]}[]}; };
export type SoloTransaction = { id:string; playerId:string; kind:'INITIAL'|'BALANCE_ADD'|'CONTRIBUTION'|'PAYOUT'|'REFUND'; amount:number; balanceAfter:number; gameId:string|null; at:number };
export type SoloSession = { id:string; ownerId:string; mode:'SOLO'; name:string; version:number; settings:SoloSettings; players:Seat[]; game:SoloHand|null; lastDealerSeat:number; nextActionAt:number|null; transactions:SoloTransaction[]; history:Record<string,unknown>[] };
export type PlayerView = ReturnType<typeof import('./runtime.js').playerView>;
export interface SoloRules extends GameRules<SoloSession,Action,PlayerView> {
  start(session:SoloSession,now:number):void;
  legal(session:SoloSession,actor:string):LegalAction[];
}
