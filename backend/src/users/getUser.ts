import { Env, UserRow } from "../types";
import { response, getUserResponse } from "../utils/response";

export async function handleGetUser(request: Request, env: Env, userId: string): Promise<Response> {
  const user = await env.expense_app_db
    .prepare(`
      SELECT id, name, email, photo_url, account_number
      FROM users
      WHERE id = ?
    `)
    .bind(userId)
    .first<UserRow>();

  if (!user) {
    return response({ error: "User not found" }, 404);
  }

  const friends = await env.expense_app_db
    .prepare(`
      SELECT friend_id
      FROM friendships
      WHERE user_id = ?
    `)
    .bind(userId)
    .all<{ friend_id: string }>();

  return response(
    getUserResponse(
      user,
      friends.results.map((friend) => friend.friend_id)
    )
  );
}