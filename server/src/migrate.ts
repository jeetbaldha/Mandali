import "dotenv/config";
import { config } from "dotenv";
import { readdir, readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import pg from "pg";

config({ path: "../.env", quiet: true });
if (!process.env.DATABASE_URL) throw new Error("Set DATABASE_URL in .env");
const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });
const client = await pool.connect();
try {
  await client.query("BEGIN");
  await client.query("SELECT pg_advisory_xact_lock(7842961)");
  await client.query(
    "CREATE TABLE IF NOT EXISTS schema_migrations (name text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())",
  );
  const directory = fileURLToPath(
    new URL("../../database/migrations/", import.meta.url),
  );
  for (const name of (await readdir(directory))
    .filter((n) => n.endsWith(".sql"))
    .sort()) {
    if (
      (
        await client.query("SELECT 1 FROM schema_migrations WHERE name=$1", [
          name,
        ])
      ).rowCount
    )
      continue;
    await client.query(await readFile(`${directory}/${name}`, "utf8"));
    await client.query("INSERT INTO schema_migrations(name) VALUES($1)", [
      name,
    ]);
    console.log(`Applied ${name}`);
  }
  await client.query("COMMIT");
} catch (error) {
  await client.query("ROLLBACK");
  throw error;
} finally {
  client.release();
  await pool.end();
}
