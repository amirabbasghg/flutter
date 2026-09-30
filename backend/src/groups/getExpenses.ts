import { Env } from "../types";
import { response } from "../utils/response";
import { requireGroupMember } from "../auth/authorization";

export async function handleGetGroupExpenses(
  request: Request,
  env: Env,
  groupId: string,
): Promise<Response> {
  const authorized = await requireGroupMember(request, env, groupId);

  if (authorized instanceof Response) {
    return authorized;
  }

  const expenses = await env.expense_app_db
    .prepare(`
      SELECT
        id,
        amount,
        paid_by_id,
        group_id,
        date_time,
        description,
        is_equal_split
      FROM expenses
      WHERE group_id = ?
      ORDER BY date_time
    `)
    .bind(groupId)
    .all<{
      id: string;
      amount: number;
      paid_by_id: string;
      group_id: string;
      date_time: string;
      description: string;
      is_equal_split: number;
    }>();

  const result = [];

  for (const expense of expenses.results) {
    const participants = await env.expense_app_db
      .prepare(`
        SELECT user_id
        FROM expense_participants
        WHERE expense_id = ?
      `)
      .bind(expense.id)
      .all<{ user_id: string }>();

    const splits = await env.expense_app_db
      .prepare(`
        SELECT user_id, amount
        FROM expense_splits
        WHERE expense_id = ?
      `)
      .bind(expense.id)
      .all<{ user_id: string; amount: number }>();

    const customSplits: Record<string, number> = {};

    for (const split of splits.results) {
      customSplits[split.user_id] = split.amount;
    }

    result.push({
      id: expense.id,
      amount: expense.amount,
      paidById: expense.paid_by_id,
      paidForIds: participants.results.map((p) => p.user_id),
      groupId: expense.group_id,
      dateTime: expense.date_time,
      description: expense.description,
      isEqualSplit: expense.is_equal_split === 1,
      customSplits,
    });
  }

  return response(result);
}
