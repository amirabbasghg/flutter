import { Env } from "../types";
import { response } from "../utils/response";
import { authenticate } from "../auth/middleware";

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

  if (query.length < 2) {
    return response({ error: "q must contain at least 2 characters" }, 400);
  }

  const pattern = `%${query}%`;

  // جست‌وجو فقط روی نام نمایشی. ایمیل عمداً جست‌وجو نمی‌شود: با آن می‌شد
  // وجود یک ایمیل مشخص در سیستم را تأیید کرد.
  const users = await env.expense_app_db
    .prepare(`
      SELECT id, name, photo_url
      FROM users
      WHERE id != ?
        AND name LIKE ? COLLATE NOCASE
      ORDER BY name COLLATE NOCASE
      LIMIT 20
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
