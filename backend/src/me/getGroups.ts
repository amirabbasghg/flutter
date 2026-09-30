import { Env } from "../types";
import { response } from "../utils/response";
import { authenticate } from "../auth/middleware";

export async function handleGetMyGroups(
  request: Request,
  env: Env,
): Promise<Response> {
  const userId = await authenticate(request, env);

  if (userId instanceof Response) {
    return userId;
  }

  const groups = await env.expense_app_db
    .prepare(`
      SELECT
        g.id,
        g.name,
        g.created_by,
        g.created_at
      FROM groups g
      INNER JOIN group_members gm ON gm.group_id = g.id
      WHERE gm.user_id = ?
      ORDER BY g.updated_at DESC
    `)
    .bind(userId)
    .all<{
      id: string;
      name: string;
      created_by: string;
      created_at: string;
    }>();

  const result = [];

  for (const group of groups.results) {
    const members = await env.expense_app_db
      .prepare(`
        SELECT user_id
        FROM group_members
        WHERE group_id = ?
      `)
      .bind(group.id)
      .all<{ user_id: string }>();

    const expenses = await env.expense_app_db
      .prepare(`
        SELECT id
        FROM expenses
        WHERE group_id = ?
        ORDER BY date_time
      `)
      .bind(group.id)
      .all<{ id: string }>();

    result.push({
      id: group.id,
      name: group.name,
      memberIds: members.results.map((member) => member.user_id),
      expenseIds: expenses.results.map((expense) => expense.id),
      createdBy: group.created_by,
      createdAt: group.created_at,
    });
  }

  return response(result);
}
