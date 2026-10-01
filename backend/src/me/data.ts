import type { Env } from "../types";

// ============================================================================
// بارگذاری داده‌های کاربر واردشده از D1.
// این توابع هم در /api/me/* و هم در /api/me/bootstrap استفاده می‌شوند تا شکل
// JSON در همه‌ی مسیرها یکسان بماند و اپ فلاتر یک مدل برای همه داشته باشد.
//
// نکته‌ی مهم: هیچ‌جا N+1 کوئری نمی‌زنیم. برای هر بخش حداکثر سه کوئری ثابت
// اجرا می‌شود و گروه‌بندی در JS انجام می‌گیرد — روی اتصال کند این تفاوت
// محسوسی دارد.
// ============================================================================

export type ContactJson = {
  id: string;
  name: string;
  email: string;
  photoURL: string | null;
  accountNumber: string | null;
};

export type GroupJson = {
  id: string;
  name: string;
  memberIds: string[];
  expenseIds: string[];
  createdBy: string;
  createdAt: string;
};

export type ExpenseJson = {
  id: string;
  amount: number;
  paidById: string;
  paidForIds: string[];
  groupId: string;
  dateTime: string;
  description: string;
  isEqualSplit: boolean;
  customSplits: Record<string, number>;
};

// کاربرانی که برای این کاربر قابل مشاهده‌اند: خودش، دوستانش و هم‌گروهی‌هایش.
// جایگزین «همه‌ی کاربران» در نسخه‌ی Firestore است — آن نسخه کل جدول users را
// به هر کلاینتی می‌داد.
export async function loadContacts(
  env: Env,
  userId: string,
): Promise<ContactJson[]> {
  const rows = await env.expense_app_db
    .prepare(
      `SELECT DISTINCT u.id, u.name, u.email, u.photo_url, u.account_number
       FROM users u
       WHERE u.id = ?1
          OR u.id IN (SELECT friend_id FROM friendships WHERE user_id = ?1)
          OR u.id IN (
               SELECT peer.user_id
               FROM group_members mine
               INNER JOIN group_members peer ON peer.group_id = mine.group_id
               WHERE mine.user_id = ?1
             )
       ORDER BY u.name COLLATE NOCASE`,
    )
    .bind(userId)
    .all<{
      id: string;
      name: string;
      email: string | null;
      photo_url: string | null;
      account_number: string | null;
    }>();

  return rows.results.map((u) => ({
    id: u.id,
    name: u.name,
    email: u.email ?? "",
    photoURL: u.photo_url,
    accountNumber: u.account_number,
  }));
}

// گروه‌هایی که کاربر عضوشان است، همراه با memberIds و expenseIds.
export async function loadGroups(env: Env, userId: string): Promise<GroupJson[]> {
  const groups = await env.expense_app_db
    .prepare(
      `SELECT g.id, g.name, g.created_by, g.created_at
       FROM groups g
       INNER JOIN group_members gm ON gm.group_id = g.id
       WHERE gm.user_id = ?
       ORDER BY g.updated_at DESC`,
    )
    .bind(userId)
    .all<{ id: string; name: string; created_by: string; created_at: string }>();

  if (groups.results.length === 0) return [];

  // اعضای همه‌ی گروه‌های کاربر در یک کوئری
  const members = await env.expense_app_db
    .prepare(
      `SELECT gm.group_id, gm.user_id
       FROM group_members gm
       WHERE gm.group_id IN (
         SELECT group_id FROM group_members WHERE user_id = ?
       )`,
    )
    .bind(userId)
    .all<{ group_id: string; user_id: string }>();

  // شناسه‌ی هزینه‌های همه‌ی گروه‌های کاربر در یک کوئری
  const expenses = await env.expense_app_db
    .prepare(
      `SELECT e.id, e.group_id
       FROM expenses e
       WHERE e.group_id IN (
         SELECT group_id FROM group_members WHERE user_id = ?
       )
       ORDER BY e.date_time`,
    )
    .bind(userId)
    .all<{ id: string; group_id: string }>();

  const membersByGroup = groupBy(members.results, (r) => r.group_id, (r) => r.user_id);
  const expensesByGroup = groupBy(expenses.results, (r) => r.group_id, (r) => r.id);

  return groups.results.map((g) => ({
    id: g.id,
    name: g.name,
    memberIds: membersByGroup.get(g.id) ?? [],
    expenseIds: expensesByGroup.get(g.id) ?? [],
    createdBy: g.created_by,
    createdAt: g.created_at,
  }));
}

// همه‌ی هزینه‌های همه‌ی گروه‌های کاربر — معادل allExpenses در اپ.
export async function loadExpenses(
  env: Env,
  userId: string,
): Promise<ExpenseJson[]> {
  const myGroups = `SELECT group_id FROM group_members WHERE user_id = ?`;

  const expenses = await env.expense_app_db
    .prepare(
      `SELECT e.id, e.amount, e.paid_by_id, e.group_id, e.date_time,
              e.description, e.is_equal_split
       FROM expenses e
       WHERE e.group_id IN (${myGroups})
       ORDER BY e.date_time`,
    )
    .bind(userId)
    .all<{
      id: string;
      amount: number;
      paid_by_id: string;
      group_id: string;
      date_time: string;
      description: string;
      is_equal_split: number;
    }>();

  if (expenses.results.length === 0) return [];

  const participants = await env.expense_app_db
    .prepare(
      `SELECT ep.expense_id, ep.user_id
       FROM expense_participants ep
       WHERE ep.expense_id IN (
         SELECT id FROM expenses WHERE group_id IN (${myGroups})
       )`,
    )
    .bind(userId)
    .all<{ expense_id: string; user_id: string }>();

  const splits = await env.expense_app_db
    .prepare(
      `SELECT es.expense_id, es.user_id, es.amount
       FROM expense_splits es
       WHERE es.expense_id IN (
         SELECT id FROM expenses WHERE group_id IN (${myGroups})
       )`,
    )
    .bind(userId)
    .all<{ expense_id: string; user_id: string; amount: number }>();

  const participantsByExpense = groupBy(
    participants.results,
    (r) => r.expense_id,
    (r) => r.user_id,
  );

  const splitsByExpense = new Map<string, Record<string, number>>();
  for (const s of splits.results) {
    const bucket = splitsByExpense.get(s.expense_id) ?? {};
    bucket[s.user_id] = s.amount;
    splitsByExpense.set(s.expense_id, bucket);
  }

  return expenses.results.map((e) => ({
    id: e.id,
    amount: e.amount,
    paidById: e.paid_by_id,
    paidForIds: participantsByExpense.get(e.id) ?? [],
    groupId: e.group_id,
    dateTime: e.date_time,
    description: e.description,
    isEqualSplit: e.is_equal_split === 1,
    customSplits: splitsByExpense.get(e.id) ?? {},
  }));
}

function groupBy<T, V>(
  rows: T[],
  key: (row: T) => string,
  value: (row: T) => V,
): Map<string, V[]> {
  const map = new Map<string, V[]>();
  for (const row of rows) {
    const k = key(row);
    const bucket = map.get(k);
    if (bucket) bucket.push(value(row));
    else map.set(k, [value(row)]);
  }
  return map;
}
