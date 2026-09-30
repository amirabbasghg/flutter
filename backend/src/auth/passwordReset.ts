import type { Env } from "../types";
import { response } from "../utils/response";
import { hashPassword, validatePassword } from "./password";
import { generateOpaqueToken, sha256Hex, RESET_TOKEN_TTL_SECONDS } from "./tokens";

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

async function getBody(request: Request): Promise<Record<string, unknown> | null> {
  const body = await request.json<Record<string, unknown>>().catch(() => null);
  return body && typeof body === "object" ? body : null;
}

// POST /api/auth/password/forgot  { email }
// همیشه ۲۰۰ برمی‌گرداند، چه ایمیل وجود داشته باشد چه نه — تا این مسیر
// برای پروب کردن «چه کسی در اپ ثبت‌نام کرده» استفاده نشود.
// توکن فقط یک‌بارمصرف و ۳۰ دقیقه‌ای است و فقط هش آن ذخیره می‌شود.
// ⚠️ فعلاً توکن در پاسخ برمی‌گردد چون سرویس ایمیل/پی‌ک (فلاتر) هنوز ساخته نشده.
//    وقتی channel واقعی اضافه شد، این بخش باید حذف شود.
export async function handleForgotPassword(
  request: Request,
  env: Env,
): Promise<Response> {
  try {
    const body = await getBody(request);
    const rawEmail = body && typeof body.email === "string" ? body.email : "";
    const email = rawEmail.trim().toLowerCase();

    const generic = response({
      success: true,
      message: "If the email is registered, a reset token was created.",
    });

    if (!EMAIL_RE.test(email)) return generic;

    // فقط کاربرانی که واقعاً رمز عبور دارند می‌توانند بازیابی کنند
    const row = await env.expense_app_db
      .prepare(
        `SELECT u.id FROM users u
         INNER JOIN auth_credentials c ON c.user_id = u.id
         WHERE u.email = ?`,
      )
      .bind(email)
      .first<{ id: string }>();
    if (!row) return generic;

    const { token, hash } = await generateOpaqueToken();
    const now = new Date();
    const expiresAt = new Date(now.getTime() + RESET_TOKEN_TTL_SECONDS * 1000);

    // اگر توکن فعالی برای این کاربر هست، اول باطل شود (یکی در هر لحظه)
    await env.expense_app_db
      .prepare(`DELETE FROM password_resets WHERE user_id = ?`)
      .bind(row.id)
      .run();

    await env.expense_app_db
      .prepare(
        `INSERT INTO password_resets (token_hash, user_id, expires_at, created_at)
         VALUES (?, ?, ?, ?)`,
      )
      .bind(hash, row.id, expiresAt.toISOString(), now.toISOString())
      .run();

    return response({
      success: true,
      message: "If the email is registered, a reset token was created.",
      devResetToken: token, // TODO: حذف شود وقتی سرویس ایمیل/پیامک وصل شد
      devExpiresAt: expiresAt.toISOString(),
    });
  } catch (error) {
    console.error("POST /api/auth/password/forgot ERROR:", error);
    return response({ error: "Failed to process request" }, 500);
  }
}

// POST /api/auth/password/reset  { token, newPassword }
// توکن یک‌بارمصرف است (با DELETE ... RETURNING اتمیک مصرف می‌شود).
// با موفقیت، همه‌ی refresh tokenهای آن کاربر باطل می‌شوند — یعنی دستگاه‌های
// دیگر مجبور به ورود مجدد می‌شوند (رفتار استاندارد «رمز را عوض کردم، همه را بیرون بینداز»).
export async function handleResetPassword(
  request: Request,
  env: Env,
): Promise<Response> {
  try {
    const body = await getBody(request);
    const token =
      body && typeof body.token === "string" && body.token ? body.token : null;
    const newPassword = body && typeof body.newPassword === "string" ? body.newPassword : "";

    if (!token) return response({ error: "token is required" }, 400);
    const passwordError = validatePassword(newPassword);
    if (passwordError) return response({ error: passwordError }, 400);

    const tokenHash = await sha256Hex(token);

    // مصرف اتمیک توکن: دو درخواست همزمان با یک توکن نمی‌توانند هر دو برنده شوند
    const row = await env.expense_app_db
      .prepare(
        `DELETE FROM password_resets WHERE token_hash = ?
         RETURNING user_id, expires_at`,
      )
      .bind(tokenHash)
      .first<{ user_id: string; expires_at: string }>();

    if (!row || new Date(row.expires_at).getTime() <= Date.now()) {
      return response({ error: "invalid-or-expired-token" }, 401);
    }

    const newHash = await hashPassword(newPassword, env);

    await env.expense_app_db.batch([
      env.expense_app_db
        .prepare(`UPDATE auth_credentials SET password_hash = ? WHERE user_id = ?`)
        .bind(newHash, row.user_id),
      env.expense_app_db
        .prepare(`DELETE FROM refresh_tokens WHERE user_id = ?`)
        .bind(row.user_id),
    ]);

    return response({ success: true });
  } catch (error) {
    console.error("POST /api/auth/password/reset ERROR:", error);
    return response({ error: "Failed to reset password" }, 500);
  }
}
