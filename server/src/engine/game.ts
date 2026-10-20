import { randomUUID } from "node:crypto";
import { createDeck, deal, shuffle, type Card } from "./cards.js";
import { roundAmount } from "./ledger.js";
import { transferToPot, splitPoints } from "./shared.js";

export const MAX_POINTS = 1_000_000_000;
export type Settings = {
  activeLimit: number;
  startingBalance: number;
  startingCall: number;
  increment: number;
  showAfter: number;
  decisionSeconds: number;
  reviewSeconds: number;
};
export const defaults: Settings = {
  activeLimit: 6,
  startingBalance: 500,
  startingCall: 20,
  increment: 20,
  showAfter: 3,
  decisionSeconds: 15,
  reviewSeconds: 20,
};
export type Player = {
  id: string;
  name: string;
  avatar: string;
  seat: number;
  balance: number;
  active: boolean;
};
export type Transaction = {
  id: string;
  playerId: string;
  kind: "INITIAL" | "BALANCE_ADD" | "CONTRIBUTION" | "PAYOUT";
  amount: number;
  balanceAfter: number;
  round: number | null;
  gameId: string | null;
  at: number;
};
export type Phase =
  | "WAITING_DEAL"
  | "DECISION"
  | "SHOW_CHOICE"
  | "REVEAL"
  | "VOTING"
  | "RESULT"
  | "PAUSED";
export type HandPlayer = {
  id: string;
  name: string;
  avatar: string;
  cards: Card[];
  folded: boolean;
  seen: boolean;
  blind: boolean;
  contributed: number;
  startingBalance: number;
  added: number;
  won: number;
};
export type Ballot = {
  number: number;
  candidates: string[];
  votes: Record<string, string>;
  counts?: Record<string, number>;
};
export type Game = {
  id: string;
  phase: Phase;
  startTime: number;
  endTime: number | null;
  startedAt: number;
  dealerId: string;
  cardCount: number;
  round: number;
  call: number;
  pot: number;
  players: HandPlayer[];
  pending: string[];
  ballots: Ballot[];
  reason?: string;
  rounds: { number: number; call: number; dealerId: string }[];
  result?: {
    kind: "WINNER" | "DRAW";
    winners: string[];
    pot: number;
    at: number;
  };
};
export type Room = {
  id: string;
  code: string;
  name: string;
  hostId: string;
  version: number;
  settings: Settings;
  players: Player[];
  game: Game | null;
  lastDealerSeat: number | null;
  transactions: Transaction[];
};

function requireRule(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}
function member(room: Room, id: string) {
  const player = room.players.find((p) => p.id === id);
  requireRule(player, "Not a room member");
  return player;
}
function hand(room: Room) {
  requireRule(room.game, "No hand in progress");
  return room.game;
}
function eligible(game: Game) {
  return game.players.filter((p) => !p.folded);
}
function phase(game: Game, value: Phase, now: number, seconds?: number) {
  game.phase = value;
  game.startTime = now;
  game.endTime = seconds === undefined ? null : now + seconds * 1000;
}
function record(
  room: Room,
  player: Player,
  kind: Transaction["kind"],
  amount: number,
  now: number,
  round: number | null = null,
) {
  room.transactions.push({
    id: randomUUID(),
    playerId: player.id,
    kind,
    amount,
    balanceAfter: player.balance,
    round,
    gameId: room.game?.id ?? null,
    at: now,
  });
}
export function addBalance(
  room: Room,
  playerId: string,
  amount: number,
  now: number,
) {
  const player = member(room, playerId);
  requireRule(
    Number.isSafeInteger(amount) &&
      amount > 0 &&
      player.balance + amount <= MAX_POINTS,
    "Invalid point addition or balance limit exceeded",
  );
  player.balance += amount;
  const hp = room.game?.players.find((p) => p.id === playerId);
  if (hp && room.game?.phase !== "RESULT") hp.added += amount;
  record(room, player, "BALANCE_ADD", amount, now);
}
export function recordInitial(room: Room, player: Player, now: number) {
  record(room, player, "INITIAL", player.balance, now);
}

export function startHand(room: Room, actor: string, now: number) {
  requireRule(actor === room.hostId, "Only the host can start");
  requireRule(
    !room.game || room.game.phase === "RESULT",
    "Previous hand is not settled",
  );
  const seats = room.players
    .filter((p) => p.active)
    .sort((a, b) => a.seat - b.seat);
  requireRule(
    seats.length >= 3 && seats.length <= room.settings.activeLimit,
    "Select 3 to the configured maximum active players",
  );
  const dealer =
    seats.find((p) => p.seat > (room.lastDealerSeat ?? -1)) ?? seats[0]!;
  const offset = seats.indexOf(dealer);
  const ordered = [...seats.slice(offset), ...seats.slice(0, offset)];
  room.lastDealerSeat = dealer.seat;
  room.game = {
    id: randomUUID(),
    phase: "WAITING_DEAL",
    startTime: now,
    endTime: null,
    startedAt: now,
    dealerId: dealer.id,
    cardCount: 0,
    round: 1,
    call: room.settings.startingCall,
    pot: 0,
    players: ordered.map((p) => ({
      id: p.id,
      name: p.name,
      avatar: p.avatar,
      cards: [],
      folded: false,
      seen: false,
      blind: false,
      contributed: 0,
      startingBalance: p.balance,
      added: 0,
      won: 0,
    })),
    pending: [],
    ballots: [],
    rounds: [],
  };
}

export function dealHand(
  room: Room,
  actor: string,
  cardCount: number,
  now: number,
) {
  const game = hand(room);
  requireRule(
    game.phase === "WAITING_DEAL" && actor === game.dealerId,
    "Only the current dealer may deal now",
  );
  requireRule(
    Number.isSafeInteger(cardCount) &&
      cardCount >= 1 &&
      cardCount * game.players.length <= 52,
    "Card count exceeds the deck",
  );
  const deck = shuffle(
    createDeck(
      ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"],
      ["S", "H", "D", "C"],
    ),
  );
  const dealt = deal(
    deck,
    game.players.map((p) => p.id),
    cardCount,
  );
  game.cardCount = cardCount;
  game.players.forEach((p) => {
    p.cards = dealt.hands[p.id]!;
  });
  beginPayment(room, now);
}
function beginPayment(room: Room, now: number) {
  const game = hand(room);
  game.call = roundAmount(
    room.settings.startingCall,
    room.settings.increment,
    game.round,
  );
  if (game.call > MAX_POINTS) {
    game.reason = "Call limit reached; pot preserved";
    phase(game, "PAUSED", now);
    return;
  }
  game.rounds.push({
    number: game.round,
    call: game.call,
    dealerId: game.dealerId,
  });
  game.pending = eligible(game).map((p) => p.id);
  phase(game, "DECISION", now, room.settings.decisionSeconds);
}
function settle(
  room: Room,
  winners: string[],
  kind: "WINNER" | "DRAW",
  now: number,
) {
  const game = hand(room);
  requireRule(!game.result && winners.length > 0, "Invalid settlement");
  const total = game.pot;
  // The game seat order starts at its dealer, making the remainder deterministic.
  const ordered = game.players.filter((p) => winners.includes(p.id));
  const shares = splitPoints(total, ordered.map(p => p.id));
  ordered.forEach((p, i) => {
    const amount = shares[i]!.amount;
    const player = member(room, p.id);
    requireRule(
      Number.isSafeInteger(player.balance + amount),
      "Point overflow",
    );
    player.balance += amount;
    p.won = amount;
    record(room, player, "PAYOUT", amount, now);
  });
  game.result = {
    kind,
    winners: ordered.map((p) => p.id),
    pot: total,
    at: now,
  };
  game.pot = 0;
  game.pending = [];
  phase(game, "RESULT", now);
}
function remainingOutcome(room: Room, now: number): boolean {
  const game = hand(room);
  const remaining = eligible(game);
  if (remaining.length === 1) {
    settle(room, [remaining[0]!.id], "WINNER", now);
    return true;
  }
  if (remaining.length === 0) {
    game.reason =
      "No eligible players remain. Host resolution required; pot preserved.";
    phase(game, "PAUSED", now);
    return true;
  }
  return false;
}
function advance(room: Room, now: number) {
  const game = hand(room);
  if (remainingOutcome(room, now)) return;
  if (game.pending.length) {
    phase(game, game.phase, now, room.settings.decisionSeconds);
    return;
  }
  if (game.phase === "DECISION" && game.round >= room.settings.showAfter) {
    game.pending = eligible(game).map((p) => p.id);
    phase(game, "SHOW_CHOICE", now, room.settings.decisionSeconds);
  } else {
    game.round += 1;
    beginPayment(room, now);
  }
}
export function act(
  room: Room,
  actor: string,
  action: "BLIND" | "PLAY" | "FOLD" | "SHOW" | "CONTINUE",
  now: number,
) {
  const game = hand(room);
  requireRule(
    game.endTime !== null && now < game.endTime,
    "Action deadline passed",
  );
  requireRule(game.pending[0] === actor, "It is not your turn");
  const player = member(room, actor);
  const hp = game.players.find((p) => p.id === actor)!;
  requireRule(hp && !hp.folded, "Player is not eligible");
  if (game.phase === "DECISION") {
    requireRule(["BLIND", "PLAY", "FOLD"].includes(action), "Invalid decision");
    if (action === "FOLD") hp.folded = true;
    else {
      requireRule(player.balance >= game.call, "INSUFFICIENT_BALANCE");
      requireRule(Number.isSafeInteger(game.pot + game.call), "Point overflow");
      const payment = transferToPot(player.balance, game.pot, game.call);
      player.balance = payment.balance;
      game.pot = payment.pot;
      hp.contributed += game.call;
      if (action === "PLAY") hp.seen = true;
      hp.blind = action === "BLIND" && !hp.seen;
      record(room, player, "CONTRIBUTION", game.call, now, game.round);
    }
  } else if (game.phase === "SHOW_CHOICE") {
    requireRule(
      action === "SHOW" || action === "CONTINUE",
      "Choose Show or Continue",
    );
    if (action === "SHOW") {
      game.pending = [];
      phase(game, "REVEAL", now, room.settings.reviewSeconds);
      return;
    }
  } else throw new Error("Actions unavailable in this phase");
  game.pending.shift();
  advance(room, now);
}
export function seeCards(room: Room, actor: string) {
  const game = hand(room);
  const player = game.players.find((p) => p.id === actor);
  requireRule(
    player &&
      !player.folded &&
      ["DECISION", "SHOW_CHOICE"].includes(game.phase),
    "Cards unavailable",
  );
  player.seen = true;
  player.blind = false;
}
function beginVote(room: Room, now: number, candidates?: string[]) {
  const game = hand(room);
  game.ballots.push({
    number: game.ballots.length + 1,
    candidates: candidates ?? eligible(game).map((p) => p.id),
    votes: {},
  });
  phase(game, "VOTING", now, 20);
}
export function vote(room: Room, actor: string, choice: string, now: number) {
  const game = hand(room);
  const ballot = game.ballots.at(-1);
  requireRule(
    game.phase === "VOTING" &&
      ballot &&
      game.endTime !== null &&
      now < game.endTime,
    "Voting is closed",
  );
  requireRule(
    eligible(game).some((p) => p.id === actor),
    "Not eligible to vote",
  );
  requireRule(!Object.hasOwn(ballot.votes, actor), "Vote already submitted");
  requireRule(choice !== actor, "Self-voting is not allowed");
  requireRule(
    ["ABSTAIN", "DRAW", ...ballot.candidates].includes(choice),
    "Invalid vote",
  );
  ballot.votes[actor] = choice;
}
function finishVote(room: Room, now: number) {
  const game = hand(room);
  const ballot = game.ballots.at(-1)!;
  const voters = eligible(game).map((p) => p.id);
  voters.forEach((id) => {
    ballot.votes[id] ??= "ABSTAIN";
  });
  const counts: Record<string, number> = { DRAW: 0, ABSTAIN: 0 };
  ballot.candidates.forEach((id) => {
    counts[id] = 0;
  });
  Object.values(ballot.votes).forEach((choice) => {
    counts[choice] = (counts[choice] ?? 0) + 1;
  });
  ballot.counts = counts;
  if (counts.DRAW! > voters.length / 2) {
    settle(room, voters, "DRAW", now);
    return;
  }
  const max = Math.max(...ballot.candidates.map((id) => counts[id]!));
  const leaders = ballot.candidates.filter((id) => counts[id] === max);
  if (max > 0 && leaders.length === 1) {
    settle(room, leaders, "WINNER", now);
    return;
  }
  if (max > 0 && game.ballots.length === 1) {
    beginVote(room, now, leaders);
    return;
  }
  game.reason = "Voting unresolved. Host may reopen voting; pot is preserved.";
  phase(game, "PAUSED", now);
}
export function reopenVote(room: Room, actor: string, now: number) {
  const game = hand(room);
  requireRule(
    actor === room.hostId &&
      game.phase === "PAUSED" &&
      eligible(game).length > 1,
    "Cannot reopen voting",
  );
  beginVote(room, now, game.ballots.at(-1)?.candidates);
  delete game.reason;
}
/** Expire at most one phase per tick. Offline players receive full turns after recovery. */
export function expire(room: Room, now: number): boolean {
  const game = room.game;
  if (!game || game.endTime === null || now < game.endTime) return false;
  if (game.phase === "DECISION") {
    const hp = game.players.find((p) => p.id === game.pending[0]);
    if (hp) hp.folded = true;
    game.pending.shift();
    advance(room, now);
  } else if (game.phase === "SHOW_CHOICE") {
    game.pending.shift();
    advance(room, now);
  } else if (game.phase === "REVEAL") beginVote(room, now);
  else if (game.phase === "VOTING") finishVote(room, now);
  return true;
}

export function snapshot(room: Room, viewer: string, now: number) {
  member(room, viewer);
  const copy = structuredClone(room);
  // Full transaction history is fetched separately; snapshots remain bounded.
  copy.transactions = copy.transactions
    .filter((t) => t.playerId === viewer)
    .slice(-30);
  if (copy.game) {
    const g = copy.game;
    const publicReveal =
      ["REVEAL", "VOTING"].includes(g.phase) || g.ballots.length > 0;
    g.players.forEach((p) => {
      if (!(p.id === viewer && p.seen) && !(publicReveal && !p.folded))
        p.cards = [];
    });
    // No ballots disclose counts or other players' choices until each ballot closes.
    g.ballots.forEach((b) => {
      if (!b.counts)
        b.votes = Object.hasOwn(b.votes, viewer)
          ? { [viewer]: b.votes[viewer]! }
          : {};
    });
  }
  return { ...copy, serverTime: now, selfId: viewer };
}
