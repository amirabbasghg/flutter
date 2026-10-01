import type { Env } from "../types";
import { response } from "../utils/response";
import { authenticate } from "../auth/middleware";
import { loadExpenses } from "./data";

// GET /api/me/expenses — هزینه‌های همه‌ی گروه‌های کاربر
export async function handleGetMyExpenses(
  request: Request,
  env: Env,
): Promise<Response> {
  try {
    const userId = await authenticate(request, env);
    if (userId instanceof Response) return userId;
    return response(await loadExpenses(env, userId));
  } catch (error) {
    console.error("GET /api/me/expenses ERROR:", error);
    return response({ error: "Failed to load expenses" }, 500);
  }
}
