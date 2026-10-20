import { config } from "dotenv";
import { Store } from "./store.js";
import { createApp } from "./app.js";
config({ path: "../.env", quiet: true });
config({ quiet: true });
if (!process.env.DATABASE_URL)
  throw new Error("Set DATABASE_URL in the root .env");
const store = new Store(process.env.DATABASE_URL);
await store.pool.query("SELECT 1 FROM schema_migrations LIMIT 1");
// This release uses one authority process. Fail instead of silently running split-brain.
const lease = await store.pool.connect();
const lock = await lease.query(
  "SELECT pg_try_advisory_lock(7842962) AS acquired",
);
if (!lock.rows[0].acquired)
  throw new Error("Another game server already holds the authority lease");
lease.on("error", () => {
  console.error("Authority lease lost");
  process.exit(1);
});
const service = createApp(store);
service.server.listen(Number(process.env.PORT ?? 3000), "0.0.0.0", () =>
  console.log(
    `Card game server listening on ${process.env.PORT ?? 3000}; virtual points only`,
  ),
);
for (const signal of ["SIGINT", "SIGTERM"])
  process.on(signal, async () => {
    await service.close();
    lease.release();
    await store.pool.end();
    process.exit(0);
  });
