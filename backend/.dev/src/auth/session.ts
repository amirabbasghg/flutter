import { Env } from "../types";

const SESSION_DURATION_MS = 30 * 24 * 60 * 60 * 1000;

function bytesToBase64Url(bytes: Uint8Array): string {
  let binary = "";

  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }

  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

async function hashToken(token: string): Promise<string> {
  const data = new TextEncoder().encode(token);

  const hash = await crypto.subtle.digest("SHA-256", data);

  return bytesToBase64Url(new Uint8Array(hash));
}

export async function createSession(
  env: Env,
  userId: string
): Promise<string> {
  const tokenBytes = crypto.getRandomValues(new Uint8Array(32));
  const token = bytesToBase64Url(tokenBytes);

  const tokenHash = await hashToken(token);

  const sessionId = crypto.randomUUID();

  const createdAt = new Date();
  const expiresAt = new Date(
    createdAt.getTime() + SESSION_DURATION_MS
  );

  await env.expense_app_db
    .prepare(`
      INSERT INTO sessions (
        id,
        user_id,
        token_hash,
        created_at,
        expires_at
      )
      VALUES (?, ?, ?, ?, ?)
    `)
    .bind(
      sessionId,
      userId,
      tokenHash,
      createdAt.toISOString(),
      expiresAt.toISOString()
    )
    .run();

  return token;
}