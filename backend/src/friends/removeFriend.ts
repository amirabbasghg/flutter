import { Env } from "../types";
import { response } from "../utils/response";

export async function handleRemoveFriend(request: Request, env: Env, userId: string, friendId: string): Promise<Response> {
  if (userId === friendId) {
    return response({ error: "Invalid friendship" }, 400);
  }

  const friendship = await env.expense_app_db
    .prepare(`SELECT 1 FROM friendships WHERE user_id = ? AND friend_id = ?`)
    .bind(userId, friendId)
    .first();

  if (!friendship) {
    return response({ error: "Friendship not found" }, 404);
  }

  await env.expense_app_db.batch([
    env.expense_app_db
      .prepare(`DELETE FROM friendships WHERE user_id = ? AND friend_id = ?`)
      .bind(userId, friendId),
    env.expense_app_db
      .prepare(`DELETE FROM friendships WHERE user_id = ? AND friend_id = ?`)
      .bind(friendId, userId),
  ]);

  return response({ message: "Friend removed successfully" });
}