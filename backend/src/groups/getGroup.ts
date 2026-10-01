import { Env } from "../types";
import { response } from "../utils/response";
import { requireGroupMember } from "../auth/authorization";

export async function handleGetGroup(
  request: Request,
  env: Env,
  groupId: string
): Promise<Response> {
  // فقط اعضای گروه می‌توانند اطلاعات گروه را ببینند
  const authorized = await requireGroupMember(request, env, groupId);
  if (authorized instanceof Response) {
    return authorized;
  }

  const group = await env.expense_app_db
    .prepare(`
      SELECT id, name, created_by, created_at
      FROM groups
      WHERE id = ?
    `)
    .bind(groupId)
    .first<{
      id: string;
      name: string;
      created_by: string;
      created_at: string;
    }>();

  if (!group) {
    return response({ error: "Group not found" }, 404);
  }

  const members = await env.expense_app_db
    .prepare(`
      SELECT user_id
      FROM group_members
      WHERE group_id = ?
    `)
    .bind(groupId)
    .all<{ user_id: string }>();

  const expenses = await env.expense_app_db
    .prepare(`
      SELECT id
      FROM expenses
      WHERE group_id = ?
      ORDER BY date_time
    `)
    .bind(groupId)
    .all<{ id: string }>();

  return response({
    id: group.id,
    name: group.name,
    memberIds: members.results.map((member) => member.user_id),
    expenseIds: expenses.results.map((expense) => expense.id),
    createdBy: group.created_by,
    createdAt: group.created_at,
  });
}