import { Env } from "../types";
import { response } from "../utils/response";
import { requireGroupCreator, groupExists } from "../auth/authorization";

export async function handleDeleteGroup(
  request: Request,
  env: Env,
  groupId: string
): Promise<Response> {
  try {
    // فقط سازنده گروه می‌تواند گروه را حذف کند
    const authorized = await requireGroupCreator(request, env, groupId);
    if (authorized instanceof Response) {
      return authorized;
    }

    // بررسی وجود گروه
    if (!(await groupExists(env, groupId))) {
      return response({ error: "Group not found" }, 404);
    }

    // بررسی اینکه گروه Expense دارد یا نه
    const expenses = await env.expense_app_db
      .prepare(`
        SELECT COUNT(*) AS count
        FROM expenses
        WHERE group_id = ?
      `)
      .bind(groupId)
      .first<{ count: number }>();

    if (expenses && expenses.count > 0) {
      return response(
        {
          error: "Cannot delete group because it has expenses",
        },
        409
      );
    }

    // حذف گروه
    // group_members به دلیل ON DELETE CASCADE
    // به صورت خودکار حذف می‌شوند.
    await env.expense_app_db
      .prepare(`
        DELETE FROM groups
        WHERE id = ?
      `)
      .bind(groupId)
      .run();

    return response({
      message: "Group deleted successfully",
    });
  } catch (error) {
    console.error("DELETE /api/groups ERROR:", error);

    return response(
      {
        error: "Failed to delete group",
        details: String(error),
      },
      500
    );
  }
}