import type { Env } from "../types";
import { response, getUserResponse } from "../utils/response";
import { hashPassword, validatePassword } from "./password";
import { issueTokens } from "./issueTokens";

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const MAX_EMAIL_LENGTH = 254;
const MAX_NAME_LENGTH = 50;

export async function handleRegister(request: Request, env: Env): Promise<Response> {
  try {
    const body = await request
      .json<{ email?: string; password?: string; name?: string }>()
      .catch(() => null);

    if (!body || typeof body.email !== "string" || typeof body.name !== "string") {
      return response({ error: "email, password and name are required" }, 400);
    }

    const email = body.email.trim().toLowerCase();
    const name = body.name.trim();

    if (!EMAIL_RE.test(email) || email.length > MAX_EMAIL_LENGTH) {
      return response({ error: "invalid-email" }, 400);
    }
    if (!name || name.length > MAX_NAME_LENGTH) {
      return response({ error: "invalid-name" }, 400);
    }
    const passwordError = validatePassword(body.password);
    if (passwordError) {
      return response({ error: passwordError }, 400);
    }
    const password = body.password as string;

    // D1/SQLite compares TEXT with BINARY collation, so `WHERE email = ?` only
    // matches an exactly-lowercase stored value. Legacy rows (pre-normalization
    // or created via Google sign-in whose token email had uppercase letters)
    // can be stored as "User@Gmail.com". Those rows never matched this query,
    // yet a later case-insensitive lookup elsewhere made the email look
    // "already used" to its real owner — and blocked re-registration attempts.
    // Match case-insensitively here so the check is consistent everywhere.
    const emailTaken = await env.expense_app_db
      .prepare(
        `SELECT u.id,
                (SELECT 1 FROM google_identities g WHERE g.user_id = u.id LIMIT 1) AS has_google_identity
         FROM users u
         WHERE LOWER(TRIM(u.email)) = ?`,
      )
      .bind(email)
      .first<{ id: string; has_google_identity: number | null }>();
    if (emailTaken) {
      // Tell the client *why* the email is taken: accounts created through
      // "Login with Google" have no password row, so a password sign-up will
      // always fail for them — the user must use the Google button instead.
      return response(
        {
          error: "email-already-in-use",
          registeredViaGoogle: emailTaken.has_google_identity === 1,
        },
        409,
      );
    }

    const nameLower = name.toLowerCase();
    const nameTaken = await env.expense_app_db
      .prepare(`SELECT 1 AS taken FROM display_names WHERE display_name_lower = ?`)
      .bind(nameLower)
      .first<{ taken: number }>();
    if (nameTaken) {
      return response({ error: "display-name-taken" }, 409);
    }

    const userId = crypto.randomUUID();
    const now = new Date().toISOString();
    const passwordHash = await hashPassword(password, env);

    // One atomic batch: if any statement fails, nothing is written.
    try {
      await env.expense_app_db.batch([
        env.expense_app_db
          .prepare(
            `INSERT INTO users (id, name, email, photo_url, account_number, created_at, updated_at)
             VALUES (?, ?, ?, NULL, NULL, ?, ?)`,
          )
          .bind(userId, name, email, now, now),
        env.expense_app_db
          .prepare(
            `INSERT INTO auth_credentials (user_id, password_hash, email_verified, created_at)
             VALUES (?, ?, 0, ?)`,
          )
          .bind(userId, passwordHash, now),
        env.expense_app_db
          .prepare(
            `INSERT INTO display_names (display_name_lower, display_name, created_at)
             VALUES (?, ?, ?)`,
          )
          .bind(nameLower, name, now),
      ]);
    } catch (error) {
      // Lost a race with a concurrent registration.
      if (String(error).includes("UNIQUE")) {
        return response({ error: "email-or-name-already-in-use" }, 409);
      }
      throw error;
    }

    const tokens = await issueTokens(env, userId);

    return response(
      {
        ...getUserResponse(
          { id: userId, name, email, photo_url: null, account_number: null },
          [],
        ),
        ...tokens,
      },
      201,
    );
  } catch (error) {
    console.error("POST /api/auth/register ERROR:", error);
    return response({ error: "Failed to register" }, 500);
  }
}
