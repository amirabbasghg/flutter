import { Env } from "../types";
import { response } from "../utils/response";
import { authenticate } from "../auth/middleware";

export async function handleUpdateMe(
  request: Request,
  env: Env,
): Promise<Response> {
  try {
    const userId = await authenticate(request, env);

    if (userId instanceof Response) {
      return userId;
    }

    const body = await request.json<{
      name?: string;
      accountNumber?: string | null;
      photoURL?: string | null;
    }>();

    if (
      body.name === undefined &&
      body.accountNumber === undefined &&
      body.photoURL === undefined
    ) {
      return response({ error: "No fields to update" }, 400);
    }

    if (body.name !== undefined && !body.name.trim()) {
      return response({ error: "Name cannot be empty" }, 400);
    }

    const existingUser = await env.expense_app_db
      .prepare(`SELECT id FROM users WHERE id = ?`)
      .bind(userId)
      .first<{ id: string }>();

    if (!existingUser) {
      return response({ error: "User not found" }, 404);
    }

    // تغییر نام باید جدول display_names را هم جابه‌جا کند، وگرنه نام قدیمی
    // برای همیشه اشغال می‌ماند و نام جدید می‌تواند با کاربر دیگری تصادم کند.
    const currentName = await env.expense_app_db
      .prepare(`SELECT name FROM users WHERE id = ?`)
      .bind(userId)
      .first<{ name: string }>();

    const newName = body.name?.trim();
    const renaming =
      newName !== undefined &&
      newName.toLowerCase() !== (currentName?.name ?? "").toLowerCase();

    if (renaming) {
      const taken = await env.expense_app_db
        .prepare(`SELECT display_name FROM display_names WHERE display_name_lower = ?`)
        .bind(newName!.toLowerCase())
        .first<{ display_name: string }>();

      if (taken) {
        return response({ error: "display-name-taken" }, 409);
      }
    }

    const fields: string[] = [];
    const values: unknown[] = [];

    if (body.name !== undefined) {
      fields.push("name = ?");
      values.push(body.name.trim());
    }

    if (body.accountNumber !== undefined) {
      fields.push("account_number = ?");
      values.push(body.accountNumber);
    }

    if (body.photoURL !== undefined) {
      fields.push("photo_url = ?");
      values.push(body.photoURL);
    }

    fields.push("updated_at = ?");
    values.push(new Date().toISOString());
    values.push(userId);

    const statements = [
      env.expense_app_db
        .prepare(`
          UPDATE users
          SET ${fields.join(", ")}
          WHERE id = ?
        `)
        .bind(...values),
    ];

    if (renaming) {
      const now = new Date().toISOString();
      statements.push(
        env.expense_app_db
          .prepare(`DELETE FROM display_names WHERE display_name_lower = ?`)
          .bind((currentName?.name ?? "").toLowerCase()),
        env.expense_app_db
          .prepare(
            `INSERT INTO display_names (display_name_lower, display_name, created_at)
             VALUES (?, ?, ?)`,
          )
          .bind(newName!.toLowerCase(), newName!, now),
      );
    } else if (newName !== undefined && newName !== currentName?.name) {
      // تغییر فقط در حروف کوچک/بزرگ (مثلاً john به John)
      statements.push(
        env.expense_app_db
          .prepare(
            `UPDATE display_names SET display_name = ? WHERE display_name_lower = ?`,
          )
          .bind(newName, newName.toLowerCase()),
      );
    }

    try {
      await env.expense_app_db.batch(statements);
    } catch (error) {
      if (String(error).includes("UNIQUE")) {
        return response({ error: "display-name-taken" }, 409);
      }
      throw error;
    }

    const user = await env.expense_app_db
      .prepare(`
        SELECT id, name, email, photo_url, account_number
        FROM users
        WHERE id = ?
      `)
      .bind(userId)
      .first<{
        id: string;
        name: string;
        email: string | null;
        photo_url: string | null;
        account_number: string | null;
      }>();

    return response({
      id: user!.id,
      name: user!.name,
      email: user!.email ?? "",
      photoURL: user!.photo_url,
      accountNumber: user!.account_number,
    });
  } catch (error) {
    console.error("PUT /api/me ERROR:", error);
    return response({ error: "Failed to update profile" }, 500);
  }
}
