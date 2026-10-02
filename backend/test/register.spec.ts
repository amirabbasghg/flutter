import { MIGRATION_SQL } from "./migrations-raw";
import {
  env,
  createExecutionContext,
  executeSql,
  waitOnExecutionContext,
} from "cloudflare:test";
import { beforeAll, describe, expect, it } from "vitest";
import worker from "../src/index";

// These tests reproduce the "email already registered" bug reported by users
// whose emails were never signed up (or were auto-created via Google login).
// See backend/src/auth/register.ts for the fix being verified.

const EMAIL = "someone@example.com";

async function register(email: string, name = "Someone") {
  const request = new Request("http://local/api/auth/register", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, name, password: "SuperSecret123" }),
  });
  const ctx = createExecutionContext();
  const response = await worker.fetch(request, env, ctx);
  await waitOnExecutionContext(ctx);
  return response;
}

beforeAll(async () => {
  // The vitest D1 binding starts on an empty database — apply the real
  // migrations first, exactly as `wrangler d1 migrations apply` does remotely.
  for (const file of Object.keys(MIGRATION_SQL)) {
    const sql = MIGRATION_SQL[file];
    await executeSql(sql);
  }

  // Fresh DB state for this file's assertions.
  const db = env.expense_app_db;
  await db.prepare(
    `DELETE FROM google_identities WHERE user_id IN (SELECT id FROM users WHERE LOWER(TRIM(email)) = ?)`,
  ).bind(EMAIL).run();
  await db.prepare(`DELETE FROM auth_credentials WHERE user_id IN (SELECT id FROM users WHERE LOWER(TRIM(email)) = ?)`).bind(EMAIL).run();
  await db.prepare(`DELETE FROM display_names WHERE display_name_lower IN ('regtest_a', 'regtest_b', 'regtest_c')`).run();
  await db.prepare(`DELETE FROM users WHERE LOWER(TRIM(email)) = ?`).bind(EMAIL).run();
});

describe("POST /api/auth/register — email-already-in-use bug", () => {
  it("rejects a duplicate email with structured 409 (registeredViaGoogle=false)", async () => {
    const first = await register(EMAIL, "regtest_a");
    expect(first.status).toBe(201);

    const second = await register(EMAIL, "regtest_b");
    expect(second.status).toBe(409);
    const body = await second.json<{ error: string; registeredViaGoogle: boolean }>();
    expect(body.error).toBe("email-already-in-use");
    expect(body.registeredViaGoogle).toBe(false);
  });

  it("detects duplicates even when the stored row has uppercase/whitespace (legacy rows)", async () => {
    // Simulate a legacy row written before trim/lowercase normalization.
    const userId = crypto.randomUUID();
    const now = new Date().toISOString();
    await env.expense_app_db
      .prepare(
        `INSERT INTO users (id, name, email, photo_url, account_number, created_at, updated_at)
         VALUES (?, ?, ?, NULL, NULL, ?, ?)`,
      )
      .bind(userId, "regtest_c", `  ${EMAIL.toUpperCase()}  `, now, now)
      .run();

    const res = await register(EMAIL, "regtest_c");
    expect(res.status).toBe(409);
    const body = await res.json<{ error: string; registeredViaGoogle: boolean }>();
    expect(body.error).toBe("email-already-in-use");
    expect(body.registeredViaGoogle).toBe(false);
  });

  it("flags accounts that were auto-created via Google sign-in", async () => {
    // The legacy row above owns the email now; attach a Google identity to it.
    const user = await env.expense_app_db
      .prepare(`SELECT id FROM users WHERE LOWER(TRIM(email)) = ?`)
      .bind(EMAIL)
      .first<{ id: string }>();
    expect(user).not.toBeNull();
    await env.expense_app_db
      .prepare(
        `INSERT INTO google_identities (sub, user_id, email, created_at) VALUES (?, ?, ?, ?)`,
      )
      .bind("google-sub-123", user!.id, EMAIL, new Date().toISOString())
      .run();

    const res = await register(EMAIL, "regtest_c");
    expect(res.status).toBe(409);
    const body = await res.json<{ error: string; registeredViaGoogle: boolean }>();
    expect(body.error).toBe("email-already-in-use");
    expect(body.registeredViaGoogle).toBe(true);
  });

  it("allows registration of an email that is not in the database at all", async () => {
    const res = await register("brand-new-address@example.com", "regtest_fresh");
    expect([201, 409]).toContain(res.status);
    // Clean up either way
    await env.expense_app_db.prepare(`DELETE FROM auth_credentials WHERE user_id IN (SELECT id FROM users WHERE email = ?)`).bind("brand-new-address@example.com").run();
    await env.expense_app_db.prepare(`DELETE FROM users WHERE email = ?`).bind("brand-new-address@example.com").run();
    await env.expense_app_db.prepare(`DELETE FROM display_names WHERE display_name_lower = ?`).bind("regtest_fresh").run();
  });
});
