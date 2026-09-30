import { Env } from "../types";
import { response } from "../utils/response";

export async function handleCheckDisplayName(
  request: Request,
  env: Env
): Promise<Response> {
  const url = new URL(request.url);
  const displayName = url.searchParams.get("name");

  if (!displayName) {
    return response({ error: "name is required" }, 400);
  }

  const displayNameLower = displayName.trim().toLowerCase();

  if (!displayNameLower) {
    return response({ error: "name is required" }, 400);
  }

  const existingName = await env.expense_app_db
    .prepare(`
      SELECT display_name
      FROM display_names
      WHERE display_name_lower = ?
    `)
    .bind(displayNameLower)
    .first<{ display_name: string }>();

  return response({
    available: !existingName,
  });
}