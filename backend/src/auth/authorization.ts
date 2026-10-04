import type { Env } from "../types";
import { response } from "../utils/response";
import { authenticate } from "./middleware";

// گروه وجود دارد؟ (برای مسیرهایی که خودشان عضویت را چک می‌کنند)
export async function groupExists(env: Env, groupId: string): Promise<boolean> {
  const group = await env.expense_app_db
    .prepare(`SELECT id FROM groups WHERE id = ?`)
    .bind(groupId)
    .first<{ id: string }>();

  return !!group;
}

// هزینه متعلق به کدام گروه است؟ null یعنی هزینه وجود ندارد.
export async function getExpenseGroupId(
  env: Env,
  expenseId: string,
): Promise<string | null> {
  const expense = await env.expense_app_db
    .prepare(`SELECT group_id FROM expenses WHERE id = ?`)
    .bind(expenseId)
    .first<{ group_id: string }>();

  return expense ? expense.group_id : null;
}

export async function isSuperAdminUser(env: Env, userId: string): Promise<boolean> {
  const adminEmail = (env.ADMIN_EMAIL ?? "mhsyny293@gmail.com").toLowerCase().trim();
  const user = await env.expense_app_db
    .prepare(`SELECT email FROM users WHERE id = ?`)
    .bind(userId)
    .first<{ email: string | null }>();
  return !!user && !!user.email && user.email.toLowerCase().trim() === adminEmail;
}

export async function requireGroupMember(
  request: Request,
  env: Env,
  groupId: string,
): Promise<string | Response> {
  const userId = await authenticate(request, env);

  if (userId instanceof Response) {
    return userId;
  }

  if (!(await groupExists(env, groupId))) {
    return response({ error: "Group not found" }, 404);
  }

  if (await isSuperAdminUser(env, userId)) {
    return userId;
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

  if (await isSuperAdminUser(env, userId)) {
    return userId;
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
