import type { Env, UserRow } from "../types";
import { response, getUserResponse } from "../utils/response";
import { authenticate } from "../auth/middleware";
import { loadContacts, loadGroups, loadExpenses } from "./data";

// GET /api/me/bootstrap
// همه‌ی چیزی که اپ برای بالا آمدن لازم دارد در یک رفت‌وبرگشت: پروفایل خودِ
// کاربر، مخاطبین، گروه‌ها و هزینه‌ها. روی اتصال کند، یک درخواست به‌جای چهار
// درخواست تفاوت محسوسی در زمان باز شدن اپ دارد.
export async function handleBootstrap(
  request: Request,
  env: Env,
): Promise<Response> {
  try {
    const userId = await authenticate(request, env);
    if (userId instanceof Response) return userId;

    const user = await env.expense_app_db
      .prepare(
        `SELECT id, name, email, photo_url, account_number
         FROM users WHERE id = ?`,
      )
      .bind(userId)
      .first<UserRow>();

    if (!user) {
      // توکن معتبر است ولی کاربر حذف شده → نشست باید باطل شود
      return response({ error: "User not found" }, 401);
    }

    const friends = await env.expense_app_db
      .prepare(`SELECT friend_id FROM friendships WHERE user_id = ?`)
      .bind(userId)
      .all<{ friend_id: string }>();

    const [contacts, groups, expenses] = await Promise.all([
      loadContacts(env, userId),
      loadGroups(env, userId),
      loadExpenses(env, userId),
    ]);

    return response({
      user: getUserResponse(
        user,
        friends.results.map((f) => f.friend_id),
      ),
      contacts,
      groups,
      expenses,
    });
  } catch (error) {
    console.error("GET /api/me/bootstrap ERROR:", error);
    return response({ error: "Failed to load data" }, 500);
  }
}
