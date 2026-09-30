import type { Env, UserRow } from "../types";
import { response, getUserResponse } from "../utils/response";
import { hashPassword, needsRehash, verifyPassword } from "./password";
import { issueTokens } from "./issueTokens";

export async function handleLogin(request: Request, env: Env): Promise<Response> {
  try {
    const body = await request
      .json<{ email?: string; password?: string }>()
      .catch(() => null);

    if (!body || typeof body.email !== "string" || typeof body.password !== "string") {
      return response({ error: "email and password are required" }, 400);
    }

    const email = body.email.trim().toLowerCase();
    const password = body.password;

    const row = await env.expense_app_db
      .prepare(
        `SELECT u.id, u.name, u.email, u.photo_url, u.account_number, c.password_hash
         FROM users u
         LEFT JOIN auth_credentials c ON c.user_id = u.id
         WHERE u.email = ?`,
      )
      .bind(email)
      .first<UserRow & { password_hash: string | null }>();

    // Same response and similar cost whether the email exists or not.
    if (!row || !row.password_hash) {
      await hashPassword(password, env);
      return response({ error: "invalid-credentials" }, 401);
    }

    const valid = await verifyPassword(password, row.password_hash, env);
    if (!valid) {
      return response({ error: "invalid-credentials" }, 401);
    }

    // Silently upgrade old hashes when the configured iteration count grows.
    if (needsRehash(row.password_hash, env)) {
      const upgraded = await hashPassword(password, env);
      await env.expense_app_db
        .prepare(`UPDATE auth_credentials SET password_hash = ? WHERE user_id = ?`)
        .bind(upgraded, row.id)
        .run();
    }

    const friends = await env.expense_app_db
      .prepare(`SELECT friend_id FROM friendships WHERE user_id = ?`)
      .bind(row.id)
      .all<{ friend_id: string }>();

    const tokens = await issueTokens(env, row.id);

    return response({
      ...getUserResponse(row, friends.results.map((f) => f.friend_id)),
      ...tokens,
    });
  } catch (error) {
    console.error("POST /api/auth/login ERROR:", error);
    return response({ error: "Failed to login" }, 500);
  }
}
