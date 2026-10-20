import { test } from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { randomUUID } from "node:crypto";
import { config } from "dotenv";
import { io, type Socket } from "socket.io-client";
import { Store } from "../src/store.js";
import { createApp } from "../src/app.js";
config({ path: "../.env", quiet: true });

test(
  "PostgreSQL and real Socket.IO: rooms, capacity, security, reconnect, votes, restart",
  { timeout: 60000 },
  async () => {
    const base = process.env.DATABASE_URL;
    assert.ok(base, "Set DATABASE_URL and run migrations first");
    const admin = new Store(base);
    const schema = `test_${randomUUID().replaceAll("-", "")}`;
    await admin.pool.query(`CREATE SCHEMA ${schema}`);
    const url = new URL(base);
    url.searchParams.set("options", `-c search_path=${schema}`);
    const store = new Store(url.toString());
    const sockets: Socket[] = [];
    let service!: ReturnType<typeof createApp>;
    try {
      for (const name of ["001_initial.sql", "002_voice_revocations.sql", "003_solo_sessions.sql"]) {
        await store.pool.query(
          await readFile(
            new URL(`../../database/migrations/${name}`, import.meta.url),
            "utf8",
          ),
        );
      }
      service = createApp(store);
      await new Promise<void>((resolve) =>
        service.server.listen(0, "127.0.0.1", resolve),
      );
      let address = `http://127.0.0.1:${(service.server.address() as any).port}`;
      async function connect(token: string) {
        const s = io(address, {
          transports: ["websocket"],
          auth: { token },
          forceNew: true,
          reconnection: false,
        });
        sockets.push(s);
        await new Promise<void>((resolve, reject) => {
          s.once("connect", resolve);
          s.once("connect_error", reject);
        });
        return s;
      }
      async function cmd(
        s: Socket,
        event: string,
        payload: any,
        roomId?: string,
        commandId = randomUUID(),
        version?: number,
      ) {
        if (roomId && version === undefined)
          version = (await store.getRoom(roomId)).version;
        return new Promise<any>((resolve, reject) => {
          const timer = setTimeout(
            () => reject(new Error(`Ack timeout: ${event}`)),
            5000,
          );
          s.emit(
            event,
            { commandId, ...(roomId ? { roomId, version } : {}), payload },
            (result: any) => {
              clearTimeout(timer);
              resolve(result);
            },
          );
        });
      }
      const sessions = await Promise.all(
        Array.from({ length: 11 }, (_, i) =>
          store.guest(`Friend ${i}`, "kite"),
        ),
      );
      const clients = await Promise.all(sessions.map((s) => connect(s.token)));
      for (const size of [2, 3, 5, 6, 10]) {
        const created = await cmd(clients[0]!, "room:create", {
          name: `${size} friends`,
        });
        assert.equal(created.ok, true);
        const id = created.roomId;
        const room = await store.getRoom(id);
        for (let i = 1; i < size; i++)
          assert.equal(
            (await cmd(clients[i]!, "room:join", { code: room.code })).ok,
            true,
          );
        const joined = await store.getRoom(id);
        assert.equal(joined.players.length, size);
        if (size === 10)
          assert.equal(
            (await cmd(clients[10]!, "room:join", { code: room.code })).ok,
            false,
          );
        assert.equal((await cmd(clients[1]!, "game:start", {}, id)).ok, false);
        await cmd(
          clients[0]!,
          "room:configure",
          {
            settings: { ...room.settings, activeLimit: 10 },
            activeIds: joined.players.map((p) => p.id),
          },
          id,
        );
        const started = await cmd(clients[0]!, "game:start", {}, id);
        assert.equal(started.ok, size >= 3);
        if (size < 3) continue;
        assert.equal(
          (await cmd(clients[0]!, "game:deal", { cardCount: 3 }, id)).ok,
          true,
        );
        assert.equal(
          (await cmd(clients[1]!, "game:action", { action: "PLAY" }, id)).ok,
          false,
        );
        assert.equal(
          (
            await cmd(
              clients[0]!,
              "game:action",
              { action: "PLAY", balance: 9999, cards: [] },
              id,
            )
          ).ok,
          false,
        );
        assert.equal(
          (await cmd(clients[10]!, "balance:add", { amount: 100 }, id)).ok,
          false,
        );
        const before = await store.getRoom(id);
        const commandId = randomUUID();
        const first = await cmd(
          clients[0]!,
          "game:action",
          { action: "BLIND" },
          id,
          commandId,
          before.version,
        );
        assert.equal(first.ok, true);
        assert.equal(
          (
            await cmd(
              clients[0]!,
              "game:action",
              { action: "BLIND" },
              id,
              commandId,
              before.version,
            )
          ).ok,
          true,
        );
        assert.equal((await store.getRoom(id)).game!.pot, 20);
        assert.equal(
          (
            await cmd(
              clients[0]!,
              "game:action",
              { action: "PLAY" },
              id,
              commandId,
              before.version,
            )
          ).ok,
          false,
        );
        assert.equal(
          (await cmd(clients[0]!, "balance:add", { amount: -100 }, id)).ok,
          false,
        );
        assert.equal(
          (await cmd(clients[0]!, "balance:add", { amount: 100 }, id)).ok,
          true,
        );
        const after = await store.getRoom(id);
        assert.equal(after.players[0]!.balance, 580);
        assert.equal(after.game!.pot, 20);
        // Reconnect authenticates the existing identity and projects its persisted private state.
        clients[0]!.disconnect();
        clients[0] = await connect(sessions[0]!.token);
        const restored = new Promise<any>((resolve) =>
          clients[0]!.once("game:state", resolve),
        );
        clients[0]!.emit("room:sync", { roomId: id }, () => {});
        const state = await restored;
        assert.equal(state.game.pot, 20);
        assert.equal(state.game.players[0].cards.length, 0);
        assert.equal(state.game.players[1].cards.length, 0);
        assert.equal(state.game.endTime, after.game!.endTime);
        if (size === 3) {
          for (let round = 1; round <= 3; round++) {
            for (let seat = round === 1 ? 1 : 0; seat < 3; seat++)
              assert.equal(
                (
                  await cmd(
                    clients[seat]!,
                    "game:action",
                    { action: "PLAY" },
                    id,
                  )
                ).ok,
                true,
              );
          }
          assert.equal((await store.getRoom(id)).game!.pot, 360);
          assert.equal(
            (await cmd(clients[0]!, "game:action", { action: "SHOW" }, id)).ok,
            true,
          );
          await store.mutate(id, null, null, (r) => {
            r.game!.endTime = Date.now() - 1;
          });
          await waitFor(
            async () => (await store.getRoom(id)).game!.phase === "VOTING",
          );
          assert.equal(
            (
              await cmd(
                clients[0]!,
                "show:vote",
                { choice: sessions[0]!.user.id },
                id,
              )
            ).ok,
            false,
          );
          assert.equal(
            (
              await cmd(
                clients[0]!,
                "show:vote",
                { choice: sessions[1]!.user.id },
                id,
              )
            ).ok,
            true,
          );
          assert.equal(
            (await cmd(clients[0]!, "show:vote", { choice: "DRAW" }, id)).ok,
            false,
          );
          assert.equal(
            (
              await cmd(
                clients[1]!,
                "show:vote",
                { choice: sessions[0]!.user.id },
                id,
              )
            ).ok,
            true,
          );
          assert.equal(
            (
              await cmd(
                clients[2]!,
                "show:vote",
                { choice: sessions[0]!.user.id },
                id,
              )
            ).ok,
            true,
          );
          await store.mutate(id, null, null, (r) => {
            r.game!.endTime = Date.now() - 1;
          });
          await waitFor(
            async () => (await store.getRoom(id)).game!.phase === "RESULT",
          );
          const final = await store.getRoom(id);
          assert.equal(final.players[0]!.balance, 840);
          assert.equal((await store.history(sessions[0]!.user.id)).length, 1);
          assert.equal(
            (
              await store.pool.query(
                "SELECT count(*)::int AS n FROM transactions WHERE game_id=$1 AND kind='PAYOUT'",
                [final.game!.id],
              )
            ).rows[0].n,
            1,
          );
        }
        if (size === 10) {
          const persisted = await store.getRoom(id);
          await service.close();
          service = createApp(store);
          await new Promise<void>((resolve) =>
            service.server.listen(0, "127.0.0.1", resolve),
          );
          address = `http://127.0.0.1:${(service.server.address() as any).port}`;
          const resumed = await connect(sessions[0]!.token);
          const updated = new Promise<any>((resolve) =>
            resumed.once("game:state", resolve),
          );
          resumed.emit("room:sync", { roomId: id }, () => {});
          const restored = await updated;
          assert.equal(restored.game.id, persisted.game!.id);
          assert.equal(restored.game.pot, persisted.game!.pot);
          assert.equal(
            restored.players[0].balance,
            persisted.players[0]!.balance,
          );
        }
      }
    } finally {
      sockets.forEach((s) => s.disconnect());
      if (service) await service.close();
      await store.pool.end();
      await admin.pool.query(`DROP SCHEMA ${schema} CASCADE`);
      await admin.pool.end();
    }
  },
);
async function waitFor(predicate: () => Promise<boolean>) {
  for (let i = 0; i < 50; i++) {
    if (await predicate()) return;
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error("Timed out waiting for server phase");
}
