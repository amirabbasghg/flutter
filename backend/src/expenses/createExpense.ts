import { Env } from "../types";
import { response } from "../utils/response";
import { isGroupMember } from "../auth/authorization";
import { authenticate } from "../auth/middleware";

type CustomSplit = {
  userId: string;
  amount: number;
};

export async function handleCreateExpense(
  request: Request,
  env: Env
): Promise<Response> {
  try {
    // هویت از توکن JWT؛ پرداخت‌کننده باید همان کاربر واردشده باشد
    const userId = await authenticate(request, env);
    if (userId instanceof Response) {
      return userId;
    }

    const body = await request.json<{
      id?: string;
      amount?: number;
      paidForIds?: string[];
      groupId?: string;
      dateTime?: string;
      description?: string;
      isEqualSplit?: boolean;
      customSplits?: CustomSplit[];
    }>();

    if (
      !body.id ||
      body.amount === undefined ||
      !body.groupId ||
      !body.dateTime ||
      body.description === undefined
    ) {
      return response(
        {
          error:
            "id, amount, groupId, dateTime and description are required",
        },
        400
      );
    }

    const paidById = userId;

    if (body.amount <= 0) {
      return response(
        { error: "Amount must be greater than zero" },
        400
      );
    }

    const paidForIds = [...new Set(body.paidForIds ?? [])];
    const isEqualSplit = body.isEqualSplit ?? true;
    const customSplits = body.customSplits ?? [];

    if (paidForIds.length === 0) {
      return response(
        { error: "At least one participant is required" },
        400
      );
    }

    // بررسی وجود گروه
    const group = await env.expense_app_db
      .prepare(`
        SELECT id
        FROM groups
        WHERE id = ?
      `)
      .bind(body.groupId)
      .first<{ id: string }>();

    if (!group) {
      return response({ error: "Group not found" }, 404);
    }

    // فقط اعضای گروه می‌توانند در آن گروه هزینه ثبت کنند
    if (!(await isGroupMember(env, userId, body.groupId))) {
      return response({ error: "Forbidden" }, 403);
    }

    // بررسی وجود پرداخت‌کننده و تمام شرکت‌کنندگان
    const userIds = [...new Set([paidById, ...paidForIds])];
    const placeholders = userIds.map(() => "?").join(", ");

    const users = await env.expense_app_db
      .prepare(`
        SELECT id
        FROM users
        WHERE id IN (${placeholders})
      `)
      .bind(...userIds)
      .all<{ id: string }>();

    if (users.results.length !== userIds.length) {
      return response(
        { error: "One or more users were not found" },
        404
      );
    }

    // بررسی اینکه همه کاربران عضو گروه باشند
    const members = await env.expense_app_db
      .prepare(`
        SELECT user_id
        FROM group_members
        WHERE group_id = ?
      `)
      .bind(body.groupId)
      .all<{ user_id: string }>();

    const memberIds = new Set(
      members.results.map((member) => member.user_id)
    );

    if (!memberIds.has(paidById)) {
      return response(
        { error: "Payer must be a member of the group" },
        400
      );
    }

    if (paidForIds.some((userId) => !memberIds.has(userId))) {
      return response(
        { error: "All participants must be members of the group" },
        400
      );
    }

    // بررسی تکراری نبودن Expense
    const existingExpense = await env.expense_app_db
      .prepare(`
        SELECT id
        FROM expenses
        WHERE id = ?
      `)
      .bind(body.id)
      .first<{ id: string }>();

    if (existingExpense) {
      return response(
        { error: "Expense already exists" },
        409
      );
    }

    // تقسیم مساوی
    if (isEqualSplit) {
      if (customSplits.length > 0) {
        return response(
          {
            error:
              "Custom splits cannot be provided for an equal split expense",
          },
          400
        );
      }
    } else {
      // تقسیم سفارشی باید برای تمام participants تعریف شده باشد
      if (customSplits.length !== paidForIds.length) {
        return response(
          {
            error:
              "Custom splits must be provided for all participants",
          },
          400
        );
      }

      const splitUserIds = customSplits.map((split) => split.userId);

      if (new Set(splitUserIds).size !== splitUserIds.length) {
        return response(
          { error: "Duplicate users in custom splits" },
          400
        );
      }

      for (const split of customSplits) {
        if (!paidForIds.includes(split.userId)) {
          return response(
            {
              error:
                "Custom split user must be one of the participants",
            },
            400
          );
        }

        if (split.amount <= 0) {
          return response(
            {
              error: "Custom split amounts must be greater than zero",
            },
            400
          );
        }
      }

      const splitTotal = customSplits.reduce(
        (sum, split) => sum + split.amount,
        0
      );

      if (Math.abs(splitTotal - body.amount) > 0.000001) {
        return response(
          {
            error: "Custom splits must equal the total expense amount",
          },
          400
        );
      }
    }

    const now = new Date().toISOString();

    const statements = [
      env.expense_app_db
        .prepare(`
          INSERT INTO expenses (
            id,
            group_id,
            amount,
            paid_by_id,
            date_time,
            description,
            is_equal_split,
            created_at,
            updated_at
          )
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        `)
        .bind(
          body.id,
          body.groupId,
          body.amount,
          paidById,
          body.dateTime,
          body.description,
          isEqualSplit ? 1 : 0,
          now,
          now
        ),
    ];

    // ثبت شرکت‌کنندگان
    for (const userId of paidForIds) {
      statements.push(
        env.expense_app_db
          .prepare(`
            INSERT INTO expense_participants (
              expense_id,
              user_id
            )
            VALUES (?, ?)
          `)
          .bind(body.id, userId)
      );
    }

    // ثبت تقسیم‌های سفارشی
    if (!isEqualSplit) {
      for (const split of customSplits) {
        statements.push(
          env.expense_app_db
            .prepare(`
              INSERT INTO expense_splits (
                expense_id,
                user_id,
                amount
              )
              VALUES (?, ?, ?)
            `)
            .bind(
              body.id,
              split.userId,
              split.amount
            )
        );
      }
    }

    await env.expense_app_db.batch(statements);

    return response(
      {
        id: body.id,
        amount: body.amount,
        paidById: paidById,
        paidForIds,
        groupId: body.groupId,
        dateTime: body.dateTime,
        description: body.description,
        isEqualSplit,
        customSplits: isEqualSplit ? [] : customSplits,
      },
      201
    );
  } catch (error) {
    console.error("POST /api/expenses ERROR:", error);

    return response(
      {
        error: "Failed to create expense",
        details: String(error),
      },
      500
    );
  }
}