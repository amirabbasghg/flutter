import { Env, UserRow } from "../types";
import { response } from "../utils/response";
import { authenticate } from "../auth/middleware";

export async function handleGetFriends(
  request: Request,
  env: Env,
  userId: string
): Promise<Response> {
  const authenticatedUserId = await authenticate(request, env);

  if (authenticatedUserId instanceof Response) {
    return authenticatedUserId;
  }

  if (authenticatedUserId !== userId) {
    return response({ error: "Forbidden" }, 403);
  }

  const user = await env.expense_app_db
    .prepare(`SELECT id FROM users WHERE id = ?`)
    .bind(userId)
    .first<{ id: string }>();

  if (!user) {
    return response({ error: "User not found" }, 404);
  }

  const friends = await env.expense_app_db
    .prepare(`
      SELECT u.id, u.name, u.email, u.photo_url, u.account_number
      FROM friendships f
      INNER JOIN users u ON u.id = f.friend_id
      WHERE f.user_id = ?
      ORDER BY u.name COLLATE NOCASE
    `)
    .bind(userId)
    .all<UserRow>();

  return response(
    friends.results.map((friend) => ({
      id: friend.id,
      name: friend.name,
      email: friend.email ?? "",
      photoURL: friend.photo_url,
      accountNumber: friend.account_number,
    }))
  );
}