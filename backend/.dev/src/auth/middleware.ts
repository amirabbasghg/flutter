import type { Env } from "../types";
import { response } from "../utils/response";
import { verifyAccessToken } from "./tokens";

// Returns the authenticated user's id, or a ready-to-return 401 Response.
//
//   const auth = await authenticate(request, env);
//   if (auth instanceof Response) return auth;
//   // auth is the user id
export async function authenticate(
  request: Request,
  env: Env,
): Promise<string | Response> {
  const header = request.headers.get("Authorization");
  if (!header) {
    return response({ error: "Authentication required" }, 401);
  }

  const match = /^Bearer\s+(\S+)$/i.exec(header.trim());
  if (!match) {
    return response({ error: "Invalid authorization header" }, 401);
  }

  const userId = await verifyAccessToken(match[1], env);
  if (!userId) {
    return response({ error: "Invalid or expired token" }, 401);
  }

  return userId;
}
