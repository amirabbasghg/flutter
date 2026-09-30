import { Env } from "../types";
import { response } from "../utils/response";

export async function handleAnonymousAuth(
  request: Request,
  env: Env
): Promise<Response> {
  try {
    const body = await request.json<{
      userId?: string;
    }>();

    if (!body.userId) {
      return response({ error: "userId is required" }, 400);
    }

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

    if (user) {
      return response({
        id: user.id,
        name: user.name,
        email: user.email ?? "",
        photoURL: user.photo_url,
        accountNumber: user.account_number,
        isNewUser: false,
      });
    }

    const now = new Date().toISOString();

    await env.expense_app_db
      .prepare(`
        INSERT INTO users (
          id,
          name,
          email,
          photo_url,
          account_number,
          created_at,
          updated_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?)
      `)
      .bind(
        body.userId,
        "",
        null,
        null,
        null,
        now,
        now
      )
      .run();

    return response(
      {
        id: body.userId,
        name: "",
        email: "",
        photoURL: null,
        accountNumber: null,
        isNewUser: true,
      },
      201
    );
  } catch (error) {
    console.error("POST /api/auth/anonymous ERROR:", error);

    return response(
      {
        error: "Failed to authenticate anonymously",
        details: String(error),
      },
      500
    );
  }
}