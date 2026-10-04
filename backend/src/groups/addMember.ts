import { Env } from "../types";
import { response } from "../utils/response";
import { requireGroupMember, groupExists } from "../auth/authorization";

export async function handleAddMember(
  request: Request,
  env: Env,
  groupId: string
): Promise<Response> {
  try {
    // هر عضوی از گروه می‌تواند عضو جدید اضافه کند
    const authorized = await requireGroupMember(request, env, groupId);
    if (authorized instanceof Response) {
      return authorized;
    }

    const body = await request.json<{
      userId?: string;
    }>();

    if (!body.userId) {
      return response({ error: "userId is required" }, 400);
    }

    // بررسی وجود گروه
    if (!(await groupExists(env, groupId))) {
      return response({ error: "Group not found" }, 404);
    }

    // بررسی وجود کاربر
    const user = await env.expense_app_db
      .prepare(`
        SELECT id, name, email, photo_url, account_number
        FROM users
        WHERE id = ?
      `)
      .bind(body.userId)
      .first<{
        id: string;
        name: string;
        email: string | null;
        photo_url: string | null;
        account_number: string | null;
      }>();

    if (!user) {
      return response({ error: "User not found" }, 404);
    }

    // بررسی اینکه کاربر قبلاً عضو گروه نباشد
    const existingMember = await env.expense_app_db
      .prepare(`
        SELECT 1
        FROM group_members
        WHERE group_id = ? AND user_id = ?
      `)
      .bind(groupId, body.userId)
      .first();

    if (existingMember) {
      return response({ error: "User is already a member of the group" }, 409);
    }

    await env.expense_app_db
      .prepare(`
        INSERT INTO group_members (group_id, user_id)
        VALUES (?, ?)
      `)
      .bind(groupId, body.userId)
      .run();

    return response(
      {
        message: "Member added successfully",
        member: {
          id: user.id,
          name: user.name,
          email: user.email ?? "",
          photoURL: user.photo_url,
          accountNumber: user.account_number,
        },
      },
      201
    );
  } catch (error) {
    console.error("POST /api/groups/:groupId/members ERROR:", error);

    return response(
      {
        error: "Failed to add member",
        details: String(error),
      },
      500
    );
  }
}