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

    await env.expense_app_db
      .prepare(`
        UPDATE users
        SET ${fields.join(", ")}
        WHERE id = ?
      `)
      .bind(...values)
      .run();

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
