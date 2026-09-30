import type { Env } from "../types";
import { response } from "../utils/response";
import { issueTokens } from "./issueTokens";
import { sha256Hex } from "./tokens";

async function readRefreshToken(request: Request): Promise<string | null> {
  const body = await request.json<{ refreshToken?: string }>().catch(() => null);
  return body && typeof body.refreshToken === "string" && body.refreshToken
    ? body.refreshToken
    : null;
}

// POST /api/auth/refresh  { refreshToken }
// Rotation: the old refresh token is deleted and a brand-new pair is issued,
// so each refresh token works exactly once.
export async function handleRefresh(request: Request, env: Env): Promise<Response> {
  try {
    const refreshToken = await readRefreshToken(request);
    if (!refreshToken) {
      return response({ error: "refreshToken is required" }, 400);
    }

    const tokenHash = await sha256Hex(refreshToken);

    // DELETE ... RETURNING is atomic: two parallel requests with the same
    // token can't both succeed.
    const row = await env.expense_app_db
      .prepare(
        `DELETE FROM refresh_tokens WHERE token_hash = ?
         RETURNING user_id, expires_at`,
      )
      .bind(tokenHash)
      .first<{ user_id: string; expires_at: string }>();

    if (!row || new Date(row.expires_at).getTime() <= Date.now()) {
      return response({ error: "invalid-refresh-token" }, 401);
    }

    return response(await issueTokens(env, row.user_id));
  } catch (error) {
    console.error("POST /api/auth/refresh ERROR:", error);
    return response({ error: "Failed to refresh token" }, 500);
  }
}

// POST /api/auth/logout  { refreshToken }
// Always answers 200 so it can't be used to probe which tokens exist.
export async function handleLogout(request: Request, env: Env): Promise<Response> {
  try {
    const refreshToken = await readRefreshToken(request);
    if (refreshToken) {
      await env.expense_app_db
        .prepare(`DELETE FROM refresh_tokens WHERE token_hash = ?`)
        .bind(await sha256Hex(refreshToken))
        .run();
    }
    return response({ success: true });
  } catch (error) {
    console.error("POST /api/auth/logout ERROR:", error);
    return response({ error: "Failed to logout" }, 500);
  }
}
