import { Env } from "../types";
import { response } from "../utils/response";

export async function handleSaveDisplayName(
  request: Request,
  env: Env
): Promise<Response> {
  try {
    const body = await request.json<{
      displayName?: string;
    }>();

    if (!body.displayName) {
      return response({ error: "displayName is required" }, 400);
    }

    const displayName = body.displayName.trim();

    if (!displayName) {
      return response({ error: "displayName is required" }, 400);
    }

    const displayNameLower = displayName.toLowerCase();

    const existingName = await env.expense_app_db
      .prepare(`
        SELECT display_name
        FROM display_names
        WHERE display_name_lower = ?
      `)
      .bind(displayNameLower)
      .first<{ display_name: string }>();

    if (existingName) {
      return response({ error: "Display name is already taken" }, 409);
    }

    const now = new Date().toISOString();

    await env.expense_app_db
      .prepare(`
        INSERT INTO display_names (
          display_name_lower,
          display_name,
          created_at
        )
        VALUES (?, ?, ?)
      `)
      .bind(displayNameLower, displayName, now)
      .run();

    return response(
      {
        displayName,
      },
      201
    );
  } catch (error) {
    console.error("POST /api/display-names ERROR:", error);

    return response(
      {
        error: "Failed to save display name",
        details: String(error),
      },
      500
    );
  }
}