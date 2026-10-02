import { Env } from "../types";
import { response } from "../utils/response";
import { authenticate } from "../auth/middleware";

// حداکثر تعداد کاربری که در یک درخواست برمی‌گردد. اپ تب «پیدا کردن» را با
// یک فهرستِ کامل پر می‌کند و جست‌وجو را محلی روی همین فهرست انجام می‌دهد
// (دقیقاً رفتار نسخه‌ی قدیمیِ Firestore)، پس اینجا سقفی سخاوتمندانه کافی است.
const MAX_RESULTS = 500;

export async function handleSearchUsers(
  request: Request,
  env: Env,
): Promise<Response> {
  const authenticatedUserId = await authenticate(request, env);

  if (authenticatedUserId instanceof Response) {
    return authenticatedUserId;
  }

  const url = new URL(request.url);
  const query = (url.searchParams.get("q") ?? "").trim();

  // بدون q یعنی «همه‌ی کاربران را بده» — اپ خودش فیلتر می‌کند. با q یعنی
  // جست‌وجوی سمت سرور (برای وقتی فهرست محلی هنوز نرسیده یا خیلی بزرگ است).
  const hasQuery = query.length > 0;
  const pattern = `%${query}%`;

  // جست‌وجو فقط روی نام نمایشی. ایمیل عمداً جست‌وجو/برگشت داده نمی‌شود: با آن
  // می‌شد وجود یک ایمیل مشخص در سیستم را تأیید کرد.
  const users = await env.expense_app_db
    .prepare(`
      SELECT id, name, photo_url
      FROM users
      WHERE id != ?
        ${hasQuery ? "AND name LIKE ?2 COLLATE NOCASE" : ""}
      ORDER BY name COLLATE NOCASE
      LIMIT ${MAX_RESULTS}
    `)
    .bind(authenticatedUserId, pattern)
    .all<{
      id: string;
      name: string;
      photo_url: string | null;
    }>();

  // ایمیل و شماره کارت در نتیجه‌ی جست‌وجو برنمی‌گردند — این‌ها فقط برای
  // دوستان و هم‌گروهی‌ها (/api/me/contacts) در دسترس‌اند.
  return response(
    users.results.map((user) => ({
      id: user.id,
      name: user.name,
      email: "",
      photoURL: user.photo_url,
      accountNumber: null,
    })),
  );
}
