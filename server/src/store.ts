import { createHash, randomBytes, randomUUID } from "node:crypto";
import pg from "pg";
import type { PoolClient } from "pg";
import { defaults, recordInitial, type Room } from "./engine/game.js";

export const hash = (value: string) =>
  createHash("sha256").update(value).digest("hex");
export type Identity = { id: string; name: string; avatar: string };

export class Store {
  readonly pool: pg.Pool;
  constructor(url: string) {
    this.pool = new pg.Pool({ connectionString: url, max: 12 });
  }
  async guest(name: string, avatar: string) {
    const id = randomUUID();
    const token = randomBytes(32).toString("base64url");
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      await client.query(
        "INSERT INTO users(id,display_name,avatar) VALUES($1,$2,$3)",
        [id, name, avatar],
      );
      await client.query(
        "INSERT INTO session_tokens VALUES($1,$2,now()+interval '30 days')",
        [hash(token), id],
      );
      await client.query("COMMIT");
      return { token, user: { id, name, avatar } };
    } catch (e) {
      await client.query("ROLLBACK");
      throw e;
    } finally {
      client.release();
    }
  }
  async authenticate(token: string): Promise<Identity> {
    const result = await this.pool.query(
      "SELECT u.id,u.display_name AS name,u.avatar FROM users u JOIN session_tokens s ON u.id=s.user_id WHERE s.token_hash=$1 AND s.expires_at>now()",
      [hash(token)],
    );
    if (!result.rows[0])
      throw new Error("Session expired. Please enter again.");
    return result.rows[0];
  }
  async getRoom(id: string): Promise<Room> {
    const result = await this.pool.query(
      "SELECT state FROM rooms WHERE id=$1",
      [id],
    );
    if (!result.rows[0]) throw new Error("Room not found");
    return result.rows[0].state;
  }
  async myRooms(id: string) {
    return (
      await this.pool.query(
        "SELECT r.id,r.code,r.name FROM rooms r JOIN room_players p ON p.room_id=r.id WHERE p.user_id=$1 ORDER BY r.created_at DESC LIMIT 20",
        [id],
      )
    ).rows;
  }
  async byCode(code: string): Promise<string> {
    const result = await this.pool.query("SELECT id FROM rooms WHERE code=$1", [
      code,
    ]);
    if (!result.rows[0]) throw new Error("Room code not found");
    return result.rows[0].id;
  }
  async create(
    user: Identity,
    commandId: string,
    fingerprint: string,
    name: string,
    balance?: number,
  ): Promise<Room> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      await client.query("SELECT pg_advisory_xact_lock(hashtext($1))", [
        user.id,
      ]);
      const previous = (
        await client.query(
          "SELECT * FROM commands WHERE user_id=$1 AND command_id=$2",
          [user.id, commandId],
        )
      ).rows[0];
      if (previous) {
        if (previous.request_hash !== fingerprint)
          throw new Error("Conflicting command ID");
        const room = (
          await client.query("SELECT state FROM rooms WHERE id=$1", [
            previous.room_id,
          ])
        ).rows[0].state;
        await client.query("COMMIT");
        return room;
      }
      const count = await client.query(
        "SELECT count(*)::int AS n FROM rooms WHERE host_id=$1",
        [user.id],
      );
      if (count.rows[0].n >= 25) throw new Error("Room creation limit reached");
      const room: Room = {
        id: randomUUID(),
        code: randomBytes(5).toString("hex").slice(0, 8).toUpperCase(),
        name,
        hostId: user.id,
        version: 0,
        settings: { ...defaults },
        players: [
          {
            ...user,
            seat: 0,
            balance: balance ?? defaults.startingBalance,
            active: true,
          },
        ],
        game: null,
        lastDealerSeat: null,
        transactions: [],
      };
      await client.query(
        "INSERT INTO rooms(id,code,name,host_id,state) VALUES($1,$2,$3,$4,$5)",
        [room.id, room.code, room.name, room.hostId, room],
      );
      recordInitial(room, room.players[0]!, Date.now());
      await this.persist(client, room);
      await client.query(
        "INSERT INTO commands(user_id,command_id,request_hash,room_id) VALUES($1,$2,$3,$4)",
        [user.id, commandId, fingerprint, room.id],
      );
      await client.query("COMMIT");
      return room;
    } catch (e) {
      await client.query("ROLLBACK");
      throw e;
    } finally {
      client.release();
    }
  }
  async mutate(
    id: string,
    actor: string | null,
    command: {
      id: string;
      hash: string;
      version?: number;
      kind: string;
      payload: unknown;
    } | null,
    change: (room: Room) => boolean | void,
  ): Promise<Room> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      // Serialize each actor's command IDs as well as each room's mutations.
      if (actor)
        await client.query("SELECT pg_advisory_xact_lock(hashtext($1))", [
          actor,
        ]);
      const result = await client.query(
        "SELECT state FROM rooms WHERE id=$1 FOR UPDATE",
        [id],
      );
      if (!result.rows[0]) throw new Error("Room not found");
      const room: Room = result.rows[0].state;
      if (command && actor) {
        const previous = (
          await client.query(
            "SELECT * FROM commands WHERE user_id=$1 AND command_id=$2",
            [actor, command.id],
          )
        ).rows[0];
        if (previous) {
          if (previous.request_hash !== command.hash || previous.room_id !== id)
            throw new Error("Conflicting command ID");
          await client.query("COMMIT");
          return room;
        }
        if (command.version !== undefined && command.version !== room.version)
          throw new Error("STALE_STATE: refresh and try again");
      }
      const changed = change(room);
      if (changed !== false) {
        room.version += 1;
        await this.persist(client, room);
      }
      if (command && actor) {
        await client.query(
          "INSERT INTO commands(user_id,command_id,request_hash,room_id) VALUES($1,$2,$3,$4)",
          [actor, command.id, command.hash, room.id],
        );
        await client.query(
          "INSERT INTO player_actions(id,room_id,game_id,user_id,kind,payload) VALUES($1,$2,$3,$4,$5,$6)",
          [
            randomUUID(),
            room.id,
            room.game?.id ?? null,
            actor,
            command.kind,
            command.payload,
          ],
        );
        if (command.kind === "room:leave")
          await client.query(
            "INSERT INTO voice_revocations(room_id,user_id,revoked_before) VALUES($1,$2,$3) ON CONFLICT(room_id,user_id) DO UPDATE SET revoked_before=excluded.revoked_before,retry_after=now()",
            [room.id, actor, Math.ceil(Date.now() / 1000)],
          );
        if (command.kind === "room:join")
          await client.query(
            "DELETE FROM voice_revocations WHERE room_id=$1 AND user_id=$2",
            [room.id, actor],
          );
      }
      await client.query("COMMIT");
      return room;
    } catch (e) {
      await client.query("ROLLBACK");
      throw e;
    } finally {
      client.release();
    }
  }
  private async persist(client: PoolClient, room: Room) {
    const game = room.game;
    if (game) {
      await client.query(
        "INSERT INTO games(id,room_id,phase,state,started_at,ended_at) VALUES($1,$2,$3,$4,to_timestamp($5/1000.0),to_timestamp($6/1000.0)) ON CONFLICT(id) DO UPDATE SET phase=excluded.phase,state=excluded.state,ended_at=excluded.ended_at",
        [
          game.id,
          room.id,
          game.phase,
          game,
          game.startedAt,
          game.result?.at ?? null,
        ],
      );
      for (const round of game.rounds)
        await client.query(
          "INSERT INTO game_rounds VALUES($1,$2,$3,$4) ON CONFLICT DO NOTHING",
          [game.id, round.number, round.call, round.dealerId],
        );
      for (const player of game.players)
        await client.query(
          "INSERT INTO player_hands VALUES($1,$2,$3) ON CONFLICT(game_id,user_id) DO UPDATE SET cards=excluded.cards",
          [game.id, player.id, JSON.stringify(player.cards)],
        );
      for (const ballot of game.ballots)
        for (const [voter, choice] of Object.entries(ballot.votes))
          await client.query(
            "INSERT INTO votes VALUES($1,$2,$3,$4) ON CONFLICT DO NOTHING",
            [game.id, ballot.number, voter, choice],
          );
      if (game.result)
        await client.query(
          "INSERT INTO game_results VALUES($1,$2) ON CONFLICT DO NOTHING",
          [game.id, game],
        );
    }
    await client.query("DELETE FROM room_players WHERE room_id=$1", [room.id]);
    for (const player of room.players)
      await client.query("INSERT INTO room_players VALUES($1,$2,$3,$4,$5)", [
        room.id,
        player.id,
        player.seat,
        player.balance,
        player.active,
      ]);
    for (const tx of room.transactions)
      await client.query(
        "INSERT INTO transactions(id,room_id,game_id,user_id,kind,round_number,amount,balance_after,created_at) VALUES($1,$2,$3,$4,$5,$6,$7,$8,to_timestamp($9/1000.0))",
        [
          tx.id,
          room.id,
          tx.gameId,
          tx.playerId,
          tx.kind,
          tx.round,
          tx.amount,
          tx.balanceAfter,
          tx.at,
        ],
      );
    room.transactions = [];
    await client.query(
      "UPDATE rooms SET state=$2,version=$3,host_id=$4 WHERE id=$1",
      [room.id, room, room.version, room.hostId],
    );
  }
  async history(userId: string) {
    // Results never return the server's private hands or individual vote identities.
    const rows = (
      await this.pool.query(
        "SELECT g.id,g.room_id,g.started_at,g.state FROM games g WHERE g.phase='RESULT' AND EXISTS (SELECT 1 FROM player_hands p WHERE p.game_id=g.id AND p.user_id=$1) ORDER BY g.started_at DESC LIMIT 50",
        [userId],
      )
    ).rows;
    return rows.map((row) => ({
      id: row.id,
      roomId: row.room_id,
      date: row.started_at,
      result: row.state.result,
      rounds: row.state.rounds,
      players: row.state.players.map((p: any) => ({
        id: p.id,
        name: p.name,
        startingBalance: p.startingBalance,
        added: p.added,
        contributed: p.contributed,
        won: p.won,
        finalBalance: p.startingBalance + p.added - p.contributed + p.won,
        net: p.won - p.contributed,
      })),
      ballots: row.state.ballots.map((b: any) => ({
        number: b.number,
        counts: b.counts,
      })),
    }));
  }
}
