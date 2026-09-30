import type { Env } from "../types";
import { response } from "../utils/response";
import { authenticate } from "./middleware";

export async function requireGroupMember(
  request: Request,
  env: Env,
  groupId: string,
): Promise<string | Response> {
  const userId = await authenticate(request, env);

  if (userId instanceof Response) {
    return userId;
  }

  const group = await env.expense_app_db
    .prepare(`SELECT id FROM groups WHERE id = ?`)
    .bind(groupId)
    .first<{ id: string }>();

  if (!group) {
    return response({ error: "Group not found" }, 404);
  }

  const member = await env.expense_app_db
    .prepare(`
      SELECT 1
      FROM group_members
      WHERE group_id = ? AND user_id = ?
    `)
    .bind(groupId, userId)
    .first();

  if (!member) {
    return response({ error: "Forbidden" }, 403);
  }

  return userId;
}

export async function requireGroupCreator(
  request: Request,
  env: Env,
  groupId: string,
): Promise<string | Response> {
  const userId = await authenticate(request, env);

  if (userId instanceof Response) {
    return userId;
  }

  const group = await env.expense_app_db
    .prepare(`
      SELECT created_by
      FROM groups
      WHERE id = ?
    `)
    .bind(groupId)
    .first<{ created_by: string }>();

  if (!group) {
    return response({ error: "Group not found" }, 404);
  }

  if (group.created_by !== userId) {
    return response({ error: "Forbidden" }, 403);
  }

  return userId;
}

export async function isGroupMember(
  env: Env,
  userId: string,
  groupId: string,
): Promise<boolean> {
  const member = await env.expense_app_db
    .prepare(`
      SELECT 1
      FROM group_members
      WHERE group_id = ? AND user_id = ?
    `)
    .bind(groupId, userId)
    .first();

  return !!member;
}
