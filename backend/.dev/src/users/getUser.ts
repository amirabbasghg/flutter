import { Env, UserRow } from "../types";
import { response, getUserResponse } from "../utils/response";
import { authenticate } from "../auth/middleware";

export async function handleGetUser(request: Request, env: Env, userId: string): Promise<Response> {
  const authenticatedUserId = await authenticate(request, env);

  if (authenticatedUserId instanceof Response) {
    return authenticatedUserId;
  }

  if (authenticatedUserId !== userId) {
    return response({ error: "Forbidden" }, 403);
  }

  const user = await env.expense_app_db
    .prepare(`
      SELECT id, name, email, photo_url, account_number
      FROM users
      WHERE id = ?
    `)
    .bind(userId)
    .first<UserRow>();

  const friends = await env.expense_app_db
    .prepare(`
      SELECT friend_id
      FROM friendships
      WHERE user_id = ?
    `)
    .bind(userId)
    .all<{ friend_id: string }>();

    if (!user) {
  return response({ error: "User not found" }, 404);
}
  return response(
    getUserResponse(
      user,
      friends.results.map((friend) => friend.friend_id)
    )
  );
}