import { Env } from "../types";
import { response } from "../utils/response";
import { requireGroupMember, groupExists } from "../auth/authorization";

export async function handleUpdateGroup(
  request: Request,
  env: Env,
  groupId: string
): Promise<Response> {
  try {
    const userId = await requireGroupMember(request, env, groupId);
    if (userId instanceof Response) {
      return userId;
    }

    const body = await request.json<{
      name?: string;
      memberIds?: string[];
    }>();

    // گرفتن گروه و اعضای فعلی
    const group = await env.expense_app_db
      .prepare(`
        SELECT id, name, created_by
        FROM groups
        WHERE id = ?
      `)
      .bind(groupId)
      .first<{ id: string; name: string; created_by: string }>();

    if (!group) {
      return response({ error: "Group not found" }, 404);
    }

    const isCreator = userId === group.created_by;

    // کاربران عادی نمی‌توانند نام گروه را تغییر دهند
    if (body.name !== undefined && body.name.trim() !== group.name) {
      if (!isCreator) {
        return response({ error: "Only group creator can rename group" }, 403);
      }
    }

    // بررسی تغییرات اعضا
    if (body.memberIds !== undefined) {
      const currentMembersResult = await env.expense_app_db
        .prepare(`
          SELECT user_id
          FROM group_members
          WHERE group_id = ?
        `)
        .bind(groupId)
        .all<{ user_id: string }>();

      const currentMemberIds = currentMembersResult.results.map((m) => m.user_id);
      const newMemberIds = [...new Set(body.memberIds)];

      // اگر کاربر سازنده نیست، نباید بقیه اعضا را حذف کند
      if (!isCreator) {
        for (const existingId of currentMemberIds) {
          if (!newMemberIds.includes(existingId) && existingId !== userId) {
            return response(
              { error: "Only group creator can remove other members" },
              403
            );
          }
        }
      }
    }

    // در صورت ارسال name، نام گروه را تغییر می‌دهیم
    if (body.name !== undefined) {
      if (!body.name.trim()) {
        return response({ error: "Group name cannot be empty" }, 400);
      }

      await env.expense_app_db
        .prepare(`
          UPDATE groups
          SET name = ?, updated_at = ?
          WHERE id = ?
        `)
        .bind(
          body.name.trim(),
          new Date().toISOString(),
          groupId
        )
        .run();
    }

    // در صورت ارسال memberIds، اعضای گروه را به‌روزرسانی می‌کنیم
    if (body.memberIds !== undefined) {
      const memberIds = [...new Set(body.memberIds)];

      // سازنده گروه نباید از اعضای گروه حذف شود
      if (!memberIds.includes(group.created_by)) {
        return response(
          { error: "Group creator must be a member of the group" },
          400
        );
      }

      // بررسی وجود تمام کاربران
      if (memberIds.length > 0) {
        const placeholders = memberIds.map(() => "?").join(", ");

        const users = await env.expense_app_db
          .prepare(`
            SELECT id
            FROM users
            WHERE id IN (${placeholders})
          `)
          .bind(...memberIds)
          .all<{ id: string }>();

        if (users.results.length !== memberIds.length) {
          return response(
            { error: "One or more members were not found" },
            404
          );
        }
      }

      // حذف اعضای فعلی و ثبت اعضای جدید
      const statements = [
        env.expense_app_db
          .prepare(`
            DELETE FROM group_members
            WHERE group_id = ?
          `)
          .bind(groupId),
      ];

      for (const memberId of memberIds) {
        statements.push(
          env.expense_app_db
            .prepare(`
              INSERT INTO group_members (group_id, user_id)
              VALUES (?, ?)
            `)
            .bind(groupId, memberId)
        );
      }

      statements.push(
        env.expense_app_db
          .prepare(`
            UPDATE groups
            SET updated_at = ?
            WHERE id = ?
          `)
          .bind(new Date().toISOString(), groupId)
      );

      await env.expense_app_db.batch(statements);
    }

    // دریافت گروه به‌روز شده
    const updatedGroup = await env.expense_app_db
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
      id: updatedGroup!.id,
      name: updatedGroup!.name,
      memberIds: members.results.map((member) => member.user_id),
      expenseIds: expenses.results.map((expense) => expense.id),
      createdBy: updatedGroup!.created_by,
      createdAt: updatedGroup!.created_at,
    });
  } catch (error) {
    console.error("PUT /api/groups ERROR:", error);

    return response(
      {
        error: "Failed to update group",
        details: String(error),
      },
      500
    );
  }
}