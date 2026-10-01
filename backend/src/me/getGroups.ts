import type { Env } from "../types";
import { response } from "../utils/response";
import { authenticate } from "../auth/middleware";
import { loadGroups } from "./data";

// GET /api/me/groups — گروه‌هایی که کاربر واردشده عضوشان است
export async function handleGetMyGroups(
  request: Request,
  env: Env,
): Promise<Response> {
  try {
    const userId = await authenticate(request, env);
    if (userId instanceof Response) return userId;
    return response(await loadGroups(env, userId));
  } catch (error) {
    console.error("GET /api/me/groups ERROR:", error);
    return response({ error: "Failed to load groups" }, 500);
  }
}
