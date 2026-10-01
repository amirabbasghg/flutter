import { Env } from "../types";
import { response } from "../utils/response";
import { requireGroupMember, getExpenseGroupId } from "../auth/authorization";

export async function handleDeleteExpense(
  request: Request,
  env: Env,
  expenseId: string
): Promise<Response> {
  try {
    // فقط اعضای گروه آن هزینه می‌توانند آن را حذف کنند
    const groupId = await getExpenseGroupId(env, expenseId);
    if (groupId === null) {
      return response({ error: "Expense not found" }, 404);
    }
    const authorized = await requireGroupMember(request, env, groupId);
    if (authorized instanceof Response) {
      return authorized;
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