import { Env, UserRow } from "../types";
import { response } from "../utils/response";
import { authenticate } from "../auth/middleware";

export async function handleAddFriend(
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

  const body = await request.json<{ friendId?: string }>();
  const friendId = body.friendId;

  if (!friendId) {
    return response({ error: "friendId is required" }, 400);
  }

  if (userId === friendId) {
    return response({ error: "A user cannot be their own friend" }, 400);
  }

  const users = await env.expense_app_db
    .prepare(`
      SELECT id, name, email, photo_url, account_number
      FROM users
      WHERE id IN (?, ?)
    `)
    .bind(userId, friendId)
    .all<UserRow>();

  if (users.results.length !== 2) {
    return response({ error: "User or friend not found" }, 404);
  }

  const existingFriendship = await env.expense_app_db
    .prepare(`
      SELECT 1
      FROM friendships
      WHERE user_id = ? AND friend_id = ?
    `)
    .bind(userId, friendId)
    .first();

  if (!existingFriendship) {
    const now = new Date().toISOString();

    await env.expense_app_db.batch([
      env.expense_app_db
        .prepare(`
          INSERT INTO friendships (user_id, friend_id, created_at)
          VALUES (?, ?, ?)
        `)
        .bind(userId, friendId, now),

      env.expense_app_db
        .prepare(`
          INSERT INTO friendships (user_id, friend_id, created_at)
          VALUES (?, ?, ?)
        `)
        .bind(friendId, userId, now),
    ]);
  }

  const friend = users.results.find(
    (user) => user.id === friendId
  )!;

  return response({
    message: "Friend added successfully",
    friend: {
      id: friend.id,
      name: friend.name,
      email: friend.email ?? "",
      photoURL: friend.photo_url,
      accountNumber: friend.account_number,
    },
  });
}