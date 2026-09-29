import { Env } from "../types";
import { response } from "../utils/response";

export async function handleGetExpense(
  request: Request,
  env: Env,
  expenseId: string
): Promise<Response> {
  try {
    // دریافت Expense
    const expense = await env.expense_app_db
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
        WHERE id = ?
      `)
      .bind(expenseId)
      .first<{
        id: string;
        amount: number;
        paid_by_id: string;
        group_id: string;
        date_time: string;
        description: string;
        is_equal_split: number;
      }>();

    if (!expense) {
      return response({ error: "Expense not found" }, 404);
    }

    // دریافت شرکت‌کنندگان
    const participants = await env.expense_app_db
      .prepare(`
        SELECT user_id
        FROM expense_participants
        WHERE expense_id = ?
      `)
      .bind(expenseId)
      .all<{ user_id: string }>();

    // دریافت تقسیم‌های سفارشی
    const splits = await env.expense_app_db
      .prepare(`
        SELECT user_id, amount
        FROM expense_splits
        WHERE expense_id = ?
      `)
      .bind(expenseId)
      .all<{
        user_id: string;
        amount: number;
      }>();

    // تبدیل custom splits به Map مورد انتظار Flutter
    const customSplits: Record<string, number> = {};

    for (const split of splits.results) {
      customSplits[split.user_id] = split.amount;
    }

    return response({
      id: expense.id,
      amount: expense.amount,
      paidById: expense.paid_by_id,
      paidForIds: participants.results.map(
        (participant) => participant.user_id
      ),
      groupId: expense.group_id,
      dateTime: expense.date_time,
      description: expense.description,
      isEqualSplit: expense.is_equal_split === 1,
      customSplits,
    });
  } catch (error) {
    console.error("GET /api/expenses/:expenseId ERROR:", error);

    return response(
      {
        error: "Failed to get expense",
        details: String(error),
      },
      500
    );
  }
}