import express from "express";
import helmet from "helmet";
import { rateLimit } from "express-rate-limit";
import { createServer } from "node:http";
import { Server } from "socket.io";
import { z } from "zod";
import {
  AccessToken,
  TrackSource,
  RoomServiceClient,
} from "livekit-server-sdk";
import { Store, hash, type Identity } from "./store.js";
import { installSolo } from './solo/service.js';
import { OnlineGameController } from './engine/online_controller.js';
import {
  act,
  addBalance,
  dealHand,
  expire,
  recordInitial,
  reopenVote,
  seeCards,
  snapshot,
  startHand,
  vote,
  MAX_POINTS,
  type Room,
} from "./engine/game.js";

const uuid = z.string().uuid();
const pointAmount = z.number().int().min(0).max(MAX_POINTS);
const settingsSchema = z
  .object({
    activeLimit: z.number().int().min(3).max(10),
    startingBalance: pointAmount,
    startingCall: z.number().int().min(1).max(100000),
    increment: z.number().int().min(1).max(100000),
    showAfter: z.number().int().min(1).max(100),
    decisionSeconds: z.union([z.literal(10), z.literal(15)]),
    reviewSeconds: z.number().int().min(15).max(20),
  })
  .strict();
const envelope = z
  .object({
    commandId: uuid,
    roomId: uuid.optional(),
    version: z.number().int().min(0).optional(),
    payload: z.unknown(),
  })
  .strict();
const payloads = {
  "room:create": z
    .object({
      name: z.string().trim().min(1).max(50),
      balance: pointAmount.optional(),
    })
    .strict(),
  "room:join": z
    .object({
      code: z
        .string()
        .trim()
        .toUpperCase()
        .regex(/^[A-Z0-9]{6,8}$/),
      balance: pointAmount.optional(),
    })
    .strict(),
  "room:configure": z
    .object({
      settings: settingsSchema,
      activeIds: z.array(uuid).min(1).max(10),
    })
    .strict(),
  "room:leave": z.object({}).strict(),
  "game:start": z.object({}).strict(),
  "game:deal": z
    .object({ cardCount: z.number().int().min(1).max(17) })
    .strict(),
  "game:action": z
    .object({ action: z.enum(["BLIND", "PLAY", "FOLD", "SHOW", "CONTINUE"]) })
    .strict(),
  "game:see": z.object({}).strict(),
  "balance:add": z.object({ amount: pointAmount.min(1) }).strict(),
  "show:vote": z
    .object({ choice: z.union([uuid, z.enum(["DRAW", "ABSTAIN"])]) })
    .strict(),
  "show:reopen": z.object({}).strict(),
};

export function createApp(store: Store) {
  const app = express();
  app.use(helmet());
  app.use(express.json({ limit: "8kb" }));
  app.use(rateLimit({ windowMs: 60000, limit: 120 }));
  const server = createServer(app);
  const io = new Server(server, {
    cors: {
      origin: (process.env.CORS_ORIGIN ?? "").split(",").filter(Boolean),
    },
    maxHttpBufferSize: 16384,
  });
  const presence = new Map<string, { mic: boolean; speaker: boolean }>();
  app.get("/health", async (_req, res) => {
    try {
      await store.pool.query("SELECT 1");
      res.json({ status: "ok", currency: "VIRTUAL_POINTS_ONLY" });
    } catch {
      res.status(503).json({ status: "database unavailable" });
    }
  });
  app.post(
    "/session/guest",
    rateLimit({ windowMs: 3600000, limit: 30 }),
    async (req, res) => {
      const parsed = z
        .object({
          name: z.string().trim().min(1).max(30),
          avatar: z
            .enum(["peacock", "lion", "lotus", "kite", "sun", "moon"])
            .default("peacock"),
        })
        .strict()
        .safeParse(req.body);
      if (!parsed.success) {
        res
          .status(400)
          .json({
            error: "Enter a name of 1–30 characters and a valid avatar",
          });
        return;
      }
      try {
        res.json(await store.guest(parsed.data.name, parsed.data.avatar));
      } catch {
        res.status(503).json({ error: "Session service unavailable" });
      }
    },
  );
  app.use(async (req, res, next) => {
    try {
      res.locals.user = await store.authenticate(
        (req.headers.authorization ?? "").replace(/^Bearer /, ""),
      );
      next();
    } catch {
      res.status(401).json({ error: "Session expired" });
    }
  });
  const closeSolo = installSolo(app, io, store);
  app.get("/session", (_req, res) => res.json(res.locals.user));
  app.get("/rooms", async (_req, res) => {
    res.json(await store.myRooms(res.locals.user.id));
  });
  app.get("/history", async (_req, res) => {
    res.json(await store.history(res.locals.user.id));
  });
  app.get("/transactions", async (_req, res) => {
    res.json(
      (
        await store.pool.query(
          "SELECT kind,amount,balance_after,created_at,game_id,round_number FROM transactions WHERE user_id=$1 ORDER BY created_at DESC LIMIT 100",
          [res.locals.user.id],
        )
      ).rows,
    );
  });
  app.post("/voice/token", async (req, res) => {
    try {
      const room = await store.getRoom(uuid.parse(req.body.roomId));
      const user: Identity = res.locals.user;
      if (!room.players.some((p) => p.id === user.id)) {
        res.status(403).json({ error: "Not a room member" });
        return;
      }
      if (
        !process.env.LIVEKIT_URL ||
        !process.env.LIVEKIT_API_KEY ||
        !process.env.LIVEKIT_API_SECRET
      ) {
        res
          .status(503)
          .json({
            error:
              "Voice is not configured. Set LIVEKIT_URL, LIVEKIT_API_KEY and LIVEKIT_API_SECRET.",
          });
        return;
      }
      const token = new AccessToken(
        process.env.LIVEKIT_API_KEY,
        process.env.LIVEKIT_API_SECRET,
        { identity: user.id, name: user.name, ttl: "10m" },
      );
      token.addGrant({
        roomJoin: true,
        room: room.id,
        canPublish: true,
        canSubscribe: true,
        canPublishData: false,
        canPublishSources: [TrackSource.MICROPHONE],
      });
      res.json({ url: process.env.LIVEKIT_URL, token: await token.toJwt() });
    } catch {
      res.status(400).json({ error: "Unable to join voice room" });
    }
  });
  app.use(
    (
      _error: unknown,
      _req: express.Request,
      res: express.Response,
      _next: express.NextFunction,
    ) => {
      res.status(500).json({ error: "Server request failed" });
    },
  );

  io.use(async (socket, next) => {
    try {
      const token = z
        .string()
        .min(20)
        .max(200)
        .parse(socket.handshake.auth.token);
      socket.data.user = await store.authenticate(token);
      socket.data.token = token;
      next();
    } catch {
      next(new Error("Invalid session"));
    }
  });
  async function publish(room: Room) {
    const sockets = await io.in(room.id).fetchSockets();
    for (const socket of sockets) {
      const id = socket.data.user.id;
      if (!room.players.some((p) => p.id === id)) {
        await socket.leave(room.id);
        continue;
      }
      socket.emit("game:state", {
        ...snapshot(room, id, Date.now()),
        presence: Object.fromEntries(
          room.players.map((p) => [
            p.id,
            {
              connected: sockets.some((s) => s.data.user.id === p.id),
              ...(presence.get(p.id) ?? { mic: false, speaker: true }),
            },
          ]),
        ),
      });
    }
  }
  io.on("connection", (socket) => {
    const user: Identity = socket.data.user;
    void socket.join(`practice:${user.id}`);
    async function selectRoom(id: string) {
      for (const previous of socket.rooms)
        if (previous !== socket.id && previous !== id && !previous.startsWith('practice:'))
          await socket.leave(previous);
      await socket.join(id);
    }
    let windowStart = Date.now();
    let events = 0;
    socket.use(async (_packet, next) => {
      if (Date.now() - windowStart >= 10000) {
        windowStart = Date.now();
        events = 0;
      }
      if (++events > 60) {
        socket.emit("server:error", "Too many requests");
        socket.disconnect(true);
        return;
      }
      try {
        await store.authenticate(socket.data.token);
        next();
      } catch {
        socket.disconnect(true);
      }
    });
    socket.on("room:sync", async (input, ack) => {
      if (typeof ack !== "function") return;
      try {
        const room = await store.getRoom(uuid.parse(input?.roomId));
        snapshot(room, user.id, Date.now());
        await selectRoom(room.id);
        await publish(room);
        ack({ ok: true });
      } catch (e) {
        ack({
          ok: false,
          error: e instanceof Error ? e.message : "Sync failed",
        });
      }
    });
    socket.on("room:disconnect", async (input, ack) => {
      if (typeof ack !== "function") return;
      const parsed = uuid.safeParse(input?.roomId);
      if (!parsed.success) {
        ack({ ok: false, error: "Invalid room" });
        return;
      }
      await socket.leave(parsed.data);
      await store
        .getRoom(parsed.data)
        .then(publish)
        .catch(() => {});
      ack({ ok: true });
    });
    for (const event of Object.keys(payloads) as (keyof typeof payloads)[]) {
      socket.on(event, async (raw, ack) => {
        if (typeof ack !== "function") return;
        try {
          const input = envelope.parse(raw);
          const payload: any = payloads[event].parse(input.payload);
          const fingerprint = hash(
            JSON.stringify({
              event,
              roomId: input.roomId,
              version: input.version,
              payload,
            }),
          );
          let room: Room;
          if (event === "room:create")
            room = await store.create(
              user,
              input.commandId,
              fingerprint,
              payload.name,
              payload.balance,
            );
          else {
            const id =
              event === "room:join"
                ? await store.byCode(payload.code)
                : uuid.parse(input.roomId);
            if (event !== "room:join" && input.version === undefined)
              throw new Error("State version required");
            room = await store.mutate(
              id,
              user.id,
              {
                id: input.commandId,
                hash: fingerprint,
                version: input.version,
                kind: event,
                payload,
              },
              (r) => {
                const me = r.players.find((p) => p.id === user.id);
                if (event === "room:join") {
                  if (me) return false;
                  if (r.players.length >= 10) throw new Error("Room is full");
                  const seat = Array.from({ length: 10 }, (_, i) => i).find(
                    (i) => !r.players.some((p) => p.seat === i),
                  )!;
                  const player = {
                    ...user,
                    seat,
                    balance: payload.balance ?? r.settings.startingBalance,
                    active:
                      !r.game &&
                      r.players.filter((p) => p.active).length <
                        r.settings.activeLimit,
                  };
                  if (!r.players.length) r.hostId = user.id;
                  r.players.push(player);
                  recordInitial(r, player, Date.now());
                  return;
                }
                if (!me) throw new Error("Not a room member");
                const now = Date.now();
                // Commands arriving after a deadline never apply to an expired phase.
                if (
                  ["game:action", "show:vote"].includes(event) &&
                  r.game?.endTime !== null &&
                  r.game?.endTime !== undefined &&
                  now >= r.game.endTime
                )
                  throw new Error("Action deadline passed");
                switch (event) {
                  case "room:configure":
                    if (
                      r.hostId !== user.id ||
                      (r.game && r.game.phase !== "RESULT")
                    )
                      throw new Error("Only host may configure between hands");
                    if (
                      new Set(payload.activeIds).size !==
                        payload.activeIds.length ||
                      payload.activeIds.some(
                        (id: string) => !r.players.some((p) => p.id === id),
                      ) ||
                      payload.activeIds.length > payload.settings.activeLimit
                    )
                      throw new Error("Invalid active seats");
                    r.settings = payload.settings;
                    r.players.forEach((p) => {
                      p.active = payload.activeIds.includes(p.id);
                    });
                    break;
                  case "room:leave":
                    if (r.game && r.game.phase !== "RESULT")
                      throw new Error(
                        "Hand in progress. You may disconnect; your seat and timer are preserved.",
                      );
                    r.players = r.players.filter((p) => p.id !== user.id);
                    if (r.hostId === user.id && r.players.length)
                      r.hostId = r.players
                        .slice()
                        .sort((a, b) => a.seat - b.seat)[0]!.id;
                    break;
                  case "game:start":
                  case "game:deal":
                  case "game:action":
                  case "game:see":
                  case "balance:add":
                  case "show:vote":
                  case "show:reopen":
                    Object.assign(r, OnlineGameController.command(r, user.id, {event,payload}, now));
                    break;
                }
              },
            );
          }
          if (event === "room:leave") await socket.leave(room.id);
          else await selectRoom(room.id);
          await publish(room);
          ack({ ok: true, roomId: room.id });
        } catch (e) {
          ack({
            ok: false,
            error:
              e instanceof z.ZodError
                ? "Invalid command payload"
                : e instanceof Error
                  ? e.message
                  : "Command failed",
          });
        }
      });
    }
    socket.on("voice:status", async (raw) => {
      const parsed = z
        .object({ roomId: uuid, mic: z.boolean(), speaker: z.boolean() })
        .strict()
        .safeParse(raw);
      if (!parsed.success || !socket.rooms.has(parsed.data.roomId)) return;
      presence.set(user.id, {
        mic: parsed.data.mic,
        speaker: parsed.data.speaker,
      });
      io.to(parsed.data.roomId).emit("voice:status", {
        playerId: user.id,
        ...presence.get(user.id),
      });
    });
    socket.on("disconnecting", () => {
      const rooms = [...socket.rooms].filter((r) => r !== socket.id);
      setTimeout(() => {
        for (const id of rooms)
          void store
            .getRoom(id)
            .then(publish)
            .catch(() => {});
      }, 0);
    });
  });
  let ticking = false;
  let revoking = false;
  const voiceAdmin =
    process.env.LIVEKIT_URL &&
    process.env.LIVEKIT_API_KEY &&
    process.env.LIVEKIT_API_SECRET
      ? new RoomServiceClient(
          process.env.LIVEKIT_URL.replace(/^ws/, "http"),
          process.env.LIVEKIT_API_KEY,
          process.env.LIVEKIT_API_SECRET,
        )
      : null;
  const voiceTimer = setInterval(async () => {
    if (!voiceAdmin || revoking) return;
    revoking = true;
    try {
      const pending = await store.pool.query(
        "SELECT * FROM voice_revocations WHERE retry_after<=now() LIMIT 20",
      );
      for (const item of pending.rows) {
        try {
          const member = await store.pool.query(
            "SELECT 1 FROM room_players WHERE room_id=$1 AND user_id=$2",
            [item.room_id, item.user_id],
          );
          if (!member.rowCount)
            await voiceAdmin.removeParticipant(item.room_id, item.user_id, {
              revokeTokenTs: BigInt(item.revoked_before),
            });
          await store.pool.query(
            "DELETE FROM voice_revocations WHERE room_id=$1 AND user_id=$2 AND revoked_before=$3",
            [item.room_id, item.user_id, item.revoked_before],
          );
        } catch {
          await store.pool.query(
            "UPDATE voice_revocations SET retry_after=now()+interval '30 seconds' WHERE room_id=$1 AND user_id=$2",
            [item.room_id, item.user_id],
          );
        }
      }
    } catch {
      console.error("Voice revocation worker unavailable");
    } finally {
      revoking = false;
    }
  }, 1000);
  const timer = setInterval(async () => {
    if (ticking) return;
    ticking = true;
    try {
      const rows = await store.pool.query(
        "SELECT id FROM rooms WHERE (state->'game'->>'endTime')::bigint <= $1",
        [Date.now()],
      );
      for (const row of rows.rows) {
        const room = await store.mutate(row.id, null, null, (r) =>
          expire(r, Date.now()),
        );
        await publish(room);
      }
    } catch (e) {
      console.error(
        "Timer worker failed",
        e instanceof Error ? e.message : "unknown",
      );
    } finally {
      ticking = false;
    }
  }, 250);
  return {
    app,
    server,
    io,
    close: async () => {
      closeSolo();
      clearInterval(timer);
      clearInterval(voiceTimer);
      await new Promise<void>((resolve) => io.close(() => resolve()));
    },
  };
}
