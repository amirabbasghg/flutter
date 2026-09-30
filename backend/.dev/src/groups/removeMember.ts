import { Env } from "../types";
import { response } from "../utils/response";

export async function handleRemoveMember(
  request: Request,
  env: Env,
  groupId: string,
  userId: string
): Promise<Response> {
  try {
    // دریافت سازنده گروه
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

    // سازنده گروه نباید از گروه حذف شود
    if (group.created_by === userId) {
      return response(
        { error: "Group creator cannot be removed from the group" },
        400
      );
    }

    // بررسی عضویت کاربر
    const member = await env.expense_app_db
      .prepare(`
        SELECT 1
        FROM group_members
        WHERE group_id = ? AND user_id = ?
      `)
      .bind(groupId, userId)
      .first();

    if (!member) {
      return response({ error: "Member not found in group" }, 404);
    }

    await env.expense_app_db
      .prepare(`
        DELETE FROM group_members
        WHERE group_id = ? AND user_id = ?
      `)
      .bind(groupId, userId)
      .run();

    return response({
      message: "Member removed successfully",
    });
  } catch (error) {
    console.error("DELETE /api/groups/:groupId/members/:userId ERROR:", error);

    return response(
      {
        error: "Failed to remove member",
        details: String(error),
      },
      500
    );
  }
}