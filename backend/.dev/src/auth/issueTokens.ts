import type { Env } from "../types";
import {
  ACCESS_TOKEN_TTL_SECONDS,
  REFRESH_TOKEN_TTL_SECONDS,
  generateOpaqueToken,
  signAccessToken,
} from "./tokens";

export type IssuedTokens = {
  accessToken: string;
  refreshToken: string;
  expiresIn: number; // access token lifetime in seconds
};

// Creates a short-lived access token (JWT) and a long-lived refresh token.
// Only the hash of the refresh token is stored in D1.
export async function issueTokens(env: Env, userId: string): Promise<IssuedTokens> {
  const accessToken = await signAccessToken(userId, env);
  const { token, hash } = await generateOpaqueToken();

  const now = new Date();
  const expiresAt = new Date(now.getTime() + REFRESH_TOKEN_TTL_SECONDS * 1000);

  await env.expense_app_db
    .prepare(
      `INSERT INTO refresh_tokens (token_hash, user_id, expires_at, created_at)
       VALUES (?, ?, ?, ?)`,
    )
    .bind(hash, userId, expiresAt.toISOString(), now.toISOString())
    .run();

  return { accessToken, refreshToken: token, expiresIn: ACCESS_TOKEN_TTL_SECONDS };
}
