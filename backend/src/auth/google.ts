import { createRemoteJWKSet, jwtVerify } from "jose";
import type { Env } from "../types";
import { response, getUserResponse } from "../utils/response";
import { issueTokens } from "./issueTokens";

// JWKS کلیدهای عمومی گوگل — jose خودش کش می‌کند و در صورت چرخش کلیدها
// دوباره fetch می‌کند. داخل Workers این fetch مجاز است.
const GOOGLE_JWKS = createRemoteJWKSet(
  new URL("https://www.googleapis.com/oauth2/v3/certs"),
);

const MAX_NAME_LENGTH = 50;

type GoogleIdTokenPayload = {
  sub: string;
  email?: string;
  email_verified?: boolean;
  name?: string;
  picture?: string;
};

// هر پلتفرم OAuth client خودش را دارد و `aud` توکن همان است، پس بیش از یک
// مقدار مجاز داریم: اندروید با client پروژه‌ی 277889096548 و وب با client
// پروژه‌ی 177838948520. GOOGLE_CLIENT_ID می‌تواند چند شناسه‌ی جداشده با ویرگول
// باشد؛ یک شناسه‌ی تنها هم مثل قبل کار می‌کند.
function allowedAudiences(env: Env): string[] {
  return (env.GOOGLE_CLIENT_ID ?? "")
    .split(",")
    .map((id) => id.trim())
    .filter((id) => id.length > 0);
}

// اعتبارسنجی کامل id_token: امضا با JWKS گوگل + issuer + audience + زمان.
async function verifyGoogleIdToken(
  idToken: string,
  env: Env,
): Promise<GoogleIdTokenPayload | null> {
  const audiences = allowedAudiences(env);
  if (audiences.length === 0) {
    throw new Error(
      "GOOGLE_CLIENT_ID is not set. Add it to wrangler.jsonc vars or .dev.vars.",
    );
  }
  try {
    const { payload } = await jwtVerify(idToken, GOOGLE_JWKS, {
      issuer: ["https://accounts.google.com", "accounts.google.com"],
      // jose قبول می‌کند که `aud` توکن با هر کدام از این‌ها برابر باشد.
      audience: audiences,
      algorithms: ["RS256"],
    });
    if (typeof payload.sub !== "string" || !payload.sub) return null;
    // email فقط وقتی معتبر است که گوگل تأیید کرده باشد
    const email =
      typeof payload.email === "string" && payload.email_verified === true
        ? payload.email.toLowerCase()
        : undefined;
    return {
      sub: payload.sub,
      email,
      email_verified: payload.email_verified === true,
      name: typeof payload.name === "string" ? payload.name : undefined,
      picture: typeof payload.picture === "string" ? payload.picture : undefined,
    };
  } catch {
    return null;
  }
}

// POST /api/auth/google  { idToken }
// - اگر sub قبلاً ثبت شده: لاگین عادی.
// - اگر کاربری با همان email وجود دارد: حساب گوگل به همان اکانت وصل می‌شود
//   (رمز عبور فعلی هم کار می‌کند).
// - در غیر این صورت: کاربر جدید ساخته می‌شود (بدون رمز عبور).
export async function handleGoogleLogin(
  request: Request,
  env: Env,
): Promise<Response> {
  try {
    const body = await request
      .json<{ idToken?: string }>()
      .catch(() => null);

    if (!body || typeof body.idToken !== "string" || !body.idToken) {
      return response({ error: "idToken is required" }, 400);
    }

    const payload = await verifyGoogleIdToken(body.idToken, env);
    if (!payload) {
      return response({ error: "invalid-google-token" }, 401);
    }

    // 1) آیا این شناسه‌ی گوگل قبلاً متصل است؟
    const identity = await env.expense_app_db
      .prepare(`SELECT user_id FROM google_identities WHERE sub = ?`)
      .bind(payload.sub)
      .first<{ user_id: string }>();

    let userId = identity?.user_id ?? null;
    let isNewUser = false;

    if (!userId) {
      const now = new Date().toISOString();
      if (payload.email) {
        // 2) کاربر با همین ایمیل وجود دارد؟ → اتصال حساب گوگل به او
        const existing = await env.expense_app_db
          .prepare(`SELECT id FROM users WHERE email = ?`)
          .bind(payload.email)
          .first<{ id: string }>();
        if (existing) {
          userId = existing.id;
          await env.expense_app_db
            .prepare(
              `INSERT INTO google_identities (sub, user_id, email, created_at)
               VALUES (?, ?, ?, ?)`,
            )
            .bind(payload.sub, userId, payload.email, now)
            .run();
        }
      }

      if (!userId) {
        // 3) کاربر جدید
        isNewUser = true;
        userId = crypto.randomUUID();
        const rawName = (payload.name ?? "").trim();
        let name = rawName.slice(0, MAX_NAME_LENGTH);
        if (!name) name = `user_${crypto.randomUUID().slice(0, 8)}`;

        // display_name باید یکتا بماند؛ در صورت تصادم عدد اضافه می‌شود
        const baseName = name;
        let candidate = name;
        for (let i = 1; ; i++) {
          const taken = await env.expense_app_db
            .prepare(
              `SELECT 1 AS taken FROM display_names WHERE display_name_lower = ?`,
            )
            .bind(candidate.toLowerCase())
            .first<{ taken: number }>();
          if (!taken) break;
          const suffix = `_${i}`;
          candidate = baseName.slice(0, MAX_NAME_LENGTH - suffix.length) + suffix;
        }

        await env.expense_app_db.batch([
          env.expense_app_db
            .prepare(
              `INSERT INTO users (id, name, email, photo_url, account_number, created_at, updated_at)
               VALUES (?, ?, ?, ?, NULL, ?, ?)`,
            )
            .bind(userId, candidate, payload.email ?? null, payload.picture ?? null, now, now),
          env.expense_app_db
            .prepare(
              `INSERT INTO google_identities (sub, user_id, email, created_at)
               VALUES (?, ?, ?, ?)`,
            )
            .bind(payload.sub, userId, payload.email ?? null, now),
          env.expense_app_db
            .prepare(
              `INSERT INTO display_names (display_name_lower, display_name, created_at)
               VALUES (?, ?, ?)`,
            )
            .bind(candidate.toLowerCase(), candidate, now),
        ]);
      } else {
        // ایمیل/عکس تازه را ذخیره می‌کنیم (بی‌خطر اگر کاربر حذف نشده باشد)
        await env.expense_app_db
          .prepare(`UPDATE users SET email = COALESCE(?, email), photo_url = COALESCE(?, photo_url), updated_at = ? WHERE id = ?`)
          .bind(payload.email ?? null, payload.picture ?? null, now, userId)
          .run();
      }
    }

    const user = await env.expense_app_db
      .prepare(`SELECT id, name, email, photo_url, account_number FROM users WHERE id = ?`)
      .bind(userId)
      .first<{ id: string; name: string; email: string | null; photo_url: string | null; account_number: string | null }>();

    if (!user) {
      // هویت گوگل به کاربری اشاره می‌کند که حذف شده
      await env.expense_app_db
        .prepare(`DELETE FROM google_identities WHERE sub = ?`)
        .bind(payload.sub)
        .run();
      return response({ error: "Account no longer exists" }, 401);
    }

    const friends = await env.expense_app_db
      .prepare(`SELECT friend_id FROM friendships WHERE user_id = ?`)
      .bind(user.id)
      .all<{ friend_id: string }>();

    const tokens = await issueTokens(env, user.id);

    return response(
      {
        ...getUserResponse(user, friends.results.map((f) => f.friend_id)),
        ...tokens,
        isNewUser,
      },
      isNewUser ? 201 : 200,
    );
  } catch (error) {
    console.error("POST /api/auth/google ERROR:", error);
    return response({ error: "Failed to login with Google" }, 500);
  }
}
