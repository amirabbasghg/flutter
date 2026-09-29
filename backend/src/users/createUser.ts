import { Env } from "../types";
import { response } from "../utils/response";

export async function handleCreateUser(request: Request, env: Env): Promise<Response> {
  try {
    const body = await request.json<{
      id?: string;
      name?: string;
      email?: string;
      photoURL?: string | null;
      accountNumber?: string | null;
    }>();

    if (!body.id || !body.name) {
      return response({ error: "id and name are required" }, 400);
    }

    const existingUser = await env.expense_app_db
      .prepare(`SELECT id FROM users WHERE id = ?`)
      .bind(body.id)
      .first<{ id: string }>();

    if (existingUser) {
      return response({ error: "User already exists" }, 409);
    }

    const now = new Date().toISOString();

    await env.expense_app_db
      .prepare(`
        INSERT INTO users (id, name, email, photo_url, account_number, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      `)
      .bind(
        body.id,
        body.name,
        body.email ?? null,
        body.photoURL ?? null,
        body.accountNumber ?? null,
        now,
        now
      )
      .run();

    return response(
      {
        id: body.id,
        name: body.name,
        email: body.email ?? "",
        photoURL: body.photoURL ?? null,
        accountNumber: body.accountNumber ?? null,
        friendIds: [],
      },
      201
    );
  } catch (error) {
    console.error("POST /api/users ERROR:", error);
    return response({ error: "Failed to create user", details: String(error) }, 500);
  }
}