import { Env } from "../types";
import { response } from "../utils/response";

export async function handleDeleteExpense(
  request: Request,
  env: Env,
  expenseId: string
): Promise<Response> {
  try {
    // بررسی وجود Expense
    const expense = await env.expense_app_db
      .prepare(`
        SELECT id
        FROM expenses
        WHERE id = ?
      `)
      .bind(expenseId)
      .first<{ id: string }>();

    if (!expense) {
      return response({ error: "Expense not found" }, 404);
    }

    // حذف Expense و اطلاعات وابسته
    await env.expense_app_db.batch([
      env.expense_app_db
        .prepare(`
          DELETE FROM expense_splits
          WHERE expense_id = ?
        `)
        .bind(expenseId),

      env.expense_app_db
        .prepare(`
          DELETE FROM expense_participants
          WHERE expense_id = ?
        `)
        .bind(expenseId),

      env.expense_app_db
        .prepare(`
          DELETE FROM expenses
          WHERE id = ?
        `)
        .bind(expenseId),
    ]);

    return response({
      message: "Expense deleted successfully",
    });
  } catch (error) {
    console.error("DELETE /api/expenses/:expenseId ERROR:", error);

    return response(
      {
        error: "Failed to delete expense",
        details: String(error),
      },
      500
    );
  }
}