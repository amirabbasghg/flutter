import { Env } from "../types";
import { response } from "../utils/response";
import { authenticate } from "../auth/middleware";

export async function handleSearchUsers(
  request: Request,
  env: Env,
): Promise<Response> {
  const authenticatedUserId = await authenticate(request, env);

  if (authenticatedUserId instanceof Response) {
    return authenticatedUserId;
  }

  const url = new URL(request.url);
  const query = (url.searchParams.get("q") ?? "").trim();

  if (query.length < 2) {
    return response({ error: "q must contain at least 2 characters" }, 400);
  }

  const pattern = `%${query}%`;

  const users = await env.expense_app_db
    .prepare(`
      SELECT id, name, email, photo_url, account_number
      FROM users
      WHERE id != ?
        AND (
          name LIKE ? COLLATE NOCASE
          OR email LIKE ? COLLATE NOCASE
        )
      ORDER BY name COLLATE NOCASE
      LIMIT 20
    `)
    .bind(authenticatedUserId, pattern, pattern)
    .all<{
      id: string;
      name: string;
      email: string | null;
      photo_url: string | null;
      account_number: string | null;
    }>();

  return response(
    users.results.map((user) => ({
      id: user.id,
      name: user.name,
      email: user.email ?? "",
      photoURL: user.photo_url,
      accountNumber: user.account_number,
    })),
  );
}
