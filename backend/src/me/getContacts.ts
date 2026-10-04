import type { Env } from "../types";
import { response } from "../utils/response";
import { authenticate } from "../auth/middleware";
import { loadContacts } from "./data";

// GET /api/me/contacts
export async function handleGetContacts(
  request: Request,
  env: Env,
): Promise<Response> {
  try {
    const userId = await authenticate(request, env);
    if (userId instanceof Response) return userId;
    return response(await loadContacts(env, userId));
  } catch (error) {
    console.error("GET /api/me/contacts ERROR:", error);
    return response({ error: "Failed to load contacts" }, 500);
  }
}
