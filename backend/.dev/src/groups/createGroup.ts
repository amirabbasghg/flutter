import { Env } from "../types";
import { response } from "../utils/response";

export async function handleCreateGroup(
  request: Request,
  env: Env
): Promise<Response> {
  try {
    const body = await request.json<{
      id?: string;
      name?: string;
      createdBy?: string;
      memberIds?: string[];
    }>();

    if (!body.id || !body.name || !body.createdBy) {
      return response(
        { error: "id, name and createdBy are required" },
        400
      );
    }

    const memberIds = body.memberIds ?? [];

    // سازنده گروه باید عضو گروه باشد
    if (!memberIds.includes(body.createdBy)) {
      memberIds.push(body.createdBy);
    }

    // بررسی وجود سازنده
    const creator = await env.expense_app_db
      .prepare(`SELECT id FROM users WHERE id = ?`)
      .bind(body.createdBy)
      .first<{ id: string }>();

    if (!creator) {
      return response({ error: "Creator not found" }, 404);
    }

    // بررسی وجود تمام اعضا
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

    // بررسی اینکه گروهی با این ID قبلاً ساخته نشده باشد
    const existingGroup = await env.expense_app_db
      .prepare(`SELECT id FROM groups WHERE id = ?`)
      .bind(body.id)
      .first<{ id: string }>();

    if (existingGroup) {
      return response({ error: "Group already exists" }, 409);
    }

    const now = new Date().toISOString();

    const statements = [
      env.expense_app_db
        .prepare(`
          INSERT INTO groups (
            id,
            name,
            created_by,
            created_at,
            updated_at
          )
          VALUES (?, ?, ?, ?, ?)
        `)
        .bind(
          body.id,
          body.name,
          body.createdBy,
          now,
          now
        ),
    ];

    // اضافه کردن اعضای گروه
    for (const memberId of memberIds) {
      statements.push(
        env.expense_app_db
          .prepare(`
            INSERT INTO group_members (group_id, user_id)
            VALUES (?, ?)
          `)
          .bind(body.id, memberId)
      );
    }

    await env.expense_app_db.batch(statements);

    return response(
      {
        id: body.id,
        name: body.name,
        createdBy: body.createdBy,
        memberIds,
        expenseIds: [],
        createdAt: now,
      },
      201
    );
  } catch (error) {
    console.error("POST /api/groups ERROR:", error);

    return response(
      {
        error: "Failed to create group",
        details: String(error),
      },
      500
    );
  }
}