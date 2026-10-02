import { Env } from "../types";
import { response } from "../utils/response";
import { authenticate } from "../auth/middleware";
import { isSuperAdminUser } from "../auth/authorization";

async function requireSuperAdmin(
  request: Request,
  env: Env,
): Promise<string | Response> {
  const userId = await authenticate(request, env);
  if (userId instanceof Response) {
    return userId;
  }
  const isAdmin = await isSuperAdminUser(env, userId);
  if (!isAdmin) {
    return response({ error: "Forbidden - Admin access required" }, 403);
  }
  return userId;
}

// GET /api/admin/bootstrap — دریافت تمام اطلاعات سیستم برای پنل مدیریت کل
export async function handleAdminBootstrap(
  request: Request,
  env: Env,
): Promise<Response> {
  const auth = await requireSuperAdmin(request, env);
  if (auth instanceof Response) return auth;

  // تمام کاربران
  const users = await env.expense_app_db
    .prepare(`
      SELECT id, name, email, photo_url, account_number, created_at
      FROM users
      ORDER BY created_at DESC
    `)
    .all<{
      id: string;
      name: string;
      email: string | null;
      photo_url: string | null;
      account_number: string | null;
      created_at: string;
    }>();

  // تمام گروه‌ها همراه اعضا
  const groups = await env.expense_app_db
    .prepare(`
      SELECT id, name, created_by, created_at
      FROM groups
      ORDER BY created_at DESC
    `)
    .all<{
      id: string;
      name: string;
      created_by: string;
      created_at: string;
    }>();

  const groupMembers = await env.expense_app_db
    .prepare(`SELECT group_id, user_id FROM group_members`)
    .all<{ group_id: string; user_id: string }>();

  const membersByGroup = new Map<string, string[]>();
  for (const gm of groupMembers.results) {
    const list = membersByGroup.get(gm.group_id) ?? [];
    list.push(gm.user_id);
    membersByGroup.set(gm.group_id, list);
  }

  // تمام هزینه‌ها
  const expenses = await env.expense_app_db
    .prepare(`
      SELECT id, amount, paid_by_id, group_id, date_time, description, is_equal_split, custom_splits
      FROM expenses
      ORDER BY date_time DESC
    `)
    .all<{
      id: string;
      amount: number;
      paid_by_id: string;
      group_id: string;
      date_time: string;
      description: string;
      is_equal_split: number;
      custom_splits: string | null;
    }>();

  const expensePayees = await env.expense_app_db
    .prepare(`SELECT expense_id, user_id FROM expense_payees`)
    .all<{ expense_id: string; user_id: string }>();

  const payeesByExpense = new Map<string, string[]>();
  for (const ep of expensePayees.results) {
    const list = payeesByExpense.get(ep.expense_id) ?? [];
    list.push(ep.user_id);
    payeesByExpense.set(ep.expense_id, list);
  }

  return response({
    users: users.results.map((u) => ({
      id: u.id,
      name: u.name,
      email: u.email ?? "",
      photoURL: u.photo_url,
      accountNumber: u.account_number,
      createdAt: u.created_at,
    })),
    groups: groups.results.map((g) => ({
      id: g.id,
      name: g.name,
      createdBy: g.created_by,
      createdAt: g.created_at,
      memberIds: membersByGroup.get(g.id) ?? [],
    })),
    expenses: expenses.results.map((e) => ({
      id: e.id,
      amount: e.amount,
      paidById: e.paid_by_id,
      groupId: e.group_id,
      dateTime: e.date_time,
      description: e.description,
      isEqualSplit: e.is_equal_split === 1,
      paidForIds: payeesByExpense.get(e.id) ?? [],
    })),
  });
}

// DELETE /api/admin/users/:userId — حذف کامل یک کاربر
export async function handleAdminDeleteUser(
  request: Request,
  env: Env,
  userId: string,
): Promise<Response> {
  const auth = await requireSuperAdmin(request, env);
  if (auth instanceof Response) return auth;

  const user = await env.expense_app_db
    .prepare(`SELECT name FROM users WHERE id = ?`)
    .bind(userId)
    .first<{ name: string }>();

  if (!user) {
    return response({ error: "User not found" }, 404);
  }

  await env.expense_app_db.batch([
    env.expense_app_db.prepare(`DELETE FROM google_identities WHERE user_id = ?`).bind(userId),
    env.expense_app_db.prepare(`DELETE FROM auth_credentials WHERE user_id = ?`).bind(userId),
    env.expense_app_db.prepare(`DELETE FROM group_members WHERE user_id = ?`).bind(userId),
    env.expense_app_db.prepare(`DELETE FROM display_names WHERE display_name_lower = ?`).bind(user.name.toLowerCase()),
    env.expense_app_db.prepare(`DELETE FROM users WHERE id = ?`).bind(userId),
  ]);

  return response({ message: "User deleted successfully" });
}

// DELETE /api/admin/groups/:groupId — حذف کامل یک گروه توسط ادمین کل
export async function handleAdminDeleteGroup(
  request: Request,
  env: Env,
  groupId: string,
): Promise<Response> {
  const auth = await requireSuperAdmin(request, env);
  if (auth instanceof Response) return auth;

  await env.expense_app_db.batch([
    env.expense_app_db.prepare(`DELETE FROM expense_payees WHERE expense_id IN (SELECT id FROM expenses WHERE group_id = ?)`).bind(groupId),
    env.expense_app_db.prepare(`DELETE FROM expenses WHERE group_id = ?`).bind(groupId),
    env.expense_app_db.prepare(`DELETE FROM group_members WHERE group_id = ?`).bind(groupId),
    env.expense_app_db.prepare(`DELETE FROM groups WHERE id = ?`).bind(groupId),
  ]);

  return response({ message: "Group deleted successfully" });
}

// DELETE /api/admin/expenses/:expenseId — حذف یک هزینه توسط ادمین کل
export async function handleAdminDeleteExpense(
  request: Request,
  env: Env,
  expenseId: string,
): Promise<Response> {
  const auth = await requireSuperAdmin(request, env);
  if (auth instanceof Response) return auth;

  await env.expense_app_db.batch([
    env.expense_app_db.prepare(`DELETE FROM expense_payees WHERE expense_id = ?`).bind(expenseId),
    env.expense_app_db.prepare(`DELETE FROM expenses WHERE id = ?`).bind(expenseId),
  ]);

  return response({ message: "Expense deleted successfully" });
}
