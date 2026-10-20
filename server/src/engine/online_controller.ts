import * as custom from './game.js';
import { GameEngine, type GameRules } from './shared.js';
type Command = { event: string; payload: any };
export const CustomOnlineRules: GameRules<custom.Room, Command, ReturnType<typeof custom.snapshot>> = {
  id: 'CUSTOM_ONLINE',
  act(room, actor, { event, payload }, now) {
    switch (event) {
      case 'game:start': return custom.startHand(room, actor, now);
      case 'game:deal': return custom.dealHand(room, actor, payload.cardCount, now);
      case 'game:action': return custom.act(room, actor, payload.action, now);
      case 'game:see': return custom.seeCards(room, actor);
      case 'balance:add': return custom.addBalance(room, actor, payload.amount, now);
      case 'show:vote': return custom.vote(room, actor, payload.choice, now);
      case 'show:reopen': return custom.reopenVote(room, actor, now);
      default: throw new Error('Unknown custom game command');
    }
  },
  expire: custom.expire,
  view: custom.snapshot,
};
export const OnlineGameController = new GameEngine(CustomOnlineRules);
