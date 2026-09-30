import { Env } from "../types";
import { response } from "../utils/response";
import { requireGroupMember, getExpenseGroupId, isGroupMember } from "../auth/authorization";

type CustomSplit = {
  userId: string;
  amount: number;
};

export async function handleUpdateExpense(
  request: Request,
  env: Env,
  expenseId: string
): Promise<Response> {
  try {
    // فقط اعضای گروه آن هزینه می‌توانند آن را ویرایش کنند
    const currentGroupId = await getExpenseGroupId(env, expenseId);
    if (currentGroupId === null) {
      return response({ error: "Expense not found" }, 404);
    }
    const authorizedId = await requireGroupMember(request, env, currentGroupId);
    if (authorizedId instanceof Response) {
      return authorizedId;
    }

    const body = await request.json<{
      amount?: number;
      paidForIds?: string[];
      groupId?: string;
      dateTime?: string;
      description?: string;
      isEqualSplit?: boolean;
      customSplits?: CustomSplit[];
    }>();

    // بررسی وجود Expense
    const existingExpense = await env.expense_app_db
      .prepare(`
        SELECT
          id,
          amount,
          paid_by_id,
          group_id,
          date_time,
          description,
          is_equal_split
        FROM expenses
        WHERE id = ?
      `)
      .bind(expenseId)
      .first<{
        id: string;
        amount: number;
        paid_by_id: string;
        group_id: string;
        date_time: string;
        description: string;
        is_equal_split: number;
      }>();

    if (!existingExpense) {
      return response({ error: "Expense not found" }, 404);
    }

    // مقادیر جدید یا مقادیر فعلی
    const amount = body.amount ?? existingExpense.amount;
    // پرداخت‌کننده قابل تغییر نیست (بدن درخواست دیگر paidById نمی‌فرستد)
    const paidById = existingExpense.paid_by_id;
    const groupId = body.groupId ?? existingExpense.group_id;
    const dateTime = body.dateTime ?? existingExpense.date_time;
    const description =
      body.description ?? existingExpense.description;

    const isEqualSplit =
      body.isEqualSplit ?? existingExpense.is_equal_split === 1;

    // دریافت participants فعلی
    const currentParticipants = await env.expense_app_db
      .prepare(`
        SELECT user_id
        FROM expense_participants
        WHERE expense_id = ?
      `)
      .bind(expenseId)
      .all<{ user_id: string }>();

    const paidForIds =
      body.paidForIds ??
      currentParticipants.results.map(
        (participant) => participant.user_id
      );

    const uniquePaidForIds = [...new Set(paidForIds)];

    if (amount <= 0) {
      return response(
        { error: "Amount must be greater than zero" },
        400
      );
    }

    if (uniquePaidForIds.length === 0) {
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
      .bind(groupId)
      .first<{ id: string }>();

    if (!group) {
      return response({ error: "Group not found" }, 404);
    }

    // اگر گروه عوض شده، کاربر فعلی باید عضو گروه جدید هم باشد
    if (groupId !== currentGroupId && !(await isGroupMember(env, authorizedId, groupId))) {
      return response(
        { error: "You must be a member of the target group" },
        403
      );
    }

    // بررسی وجود کاربران
    const userIds = [...new Set([paidById, ...uniquePaidForIds])];
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

    // بررسی اعضای گروه
    const members = await env.expense_app_db
      .prepare(`
        SELECT user_id
        FROM group_members
        WHERE group_id = ?
      `)
      .bind(groupId)
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

    if (uniquePaidForIds.some((userId) => !memberIds.has(userId))) {
      return response(
        { error: "All participants must be members of the group" },
        400
      );
    }

    // دریافت custom splits فعلی
    const currentSplits = await env.expense_app_db
      .prepare(`
        SELECT user_id, amount
        FROM expense_splits
        WHERE expense_id = ?
      `)
      .bind(expenseId)
      .all<{
        user_id: string;
        amount: number;
      }>();

    const customSplits =
      body.customSplits ??
      currentSplits.results.map((split) => ({
        userId: split.user_id,
        amount: split.amount,
      }));

    // اعتبارسنجی تقسیم
    if (isEqualSplit) {
      if (body.customSplits !== undefined && customSplits.length > 0) {
        return response(
          {
            error:
              "Custom splits cannot be provided for an equal split expense",
          },
          400
        );
      }
    } else {
      if (customSplits.length !== uniquePaidForIds.length) {
        return response(
          {
            error:
              "Custom splits must be provided for all participants",
          },
          400
        );
      }

      const splitUserIds = customSplits.map(
        (split) => split.userId
      );

      if (
        new Set(splitUserIds).size !== splitUserIds.length
      ) {
        return response(
          { error: "Duplicate users in custom splits" },
          400
        );
      }

      for (const split of customSplits) {
        if (!uniquePaidForIds.includes(split.userId)) {
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
              error:
                "Custom split amounts must be greater than zero",
            },
            400
          );
        }
      }

      const splitTotal = customSplits.reduce(
        (sum, split) => sum + split.amount,
        0
      );

      if (Math.abs(splitTotal - amount) > 0.000001) {
        return response(
          {
            error:
              "Custom splits must equal the total expense amount",
          },
          400
        );
      }
    }

    const now = new Date().toISOString();

    const statements = [
      // به‌روزرسانی اطلاعات اصلی Expense
      env.expense_app_db
        .prepare(`
          UPDATE expenses
          SET
            group_id = ?,
            amount = ?,
            paid_by_id = ?,
            date_time = ?,
            description = ?,
            is_equal_split = ?,
            updated_at = ?
          WHERE id = ?
        `)
        .bind(
          groupId,
          amount,
          paidById,
          dateTime,
          description,
          isEqualSplit ? 1 : 0,
          now,
          expenseId
        ),

      // حذف participants قبلی
      env.expense_app_db
        .prepare(`
          DELETE FROM expense_participants
          WHERE expense_id = ?
        `)
        .bind(expenseId),

      // حذف custom splits قبلی
      env.expense_app_db
        .prepare(`
          DELETE FROM expense_splits
          WHERE expense_id = ?
        `)
        .bind(expenseId),
    ];

    // ثبت participants جدید
    for (const userId of uniquePaidForIds) {
      statements.push(
        env.expense_app_db
          .prepare(`
            INSERT INTO expense_participants (
              expense_id,
              user_id
            )
            VALUES (?, ?)
          `)
          .bind(expenseId, userId)
      );
    }

    // ثبت custom splits جدید
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
              expenseId,
              split.userId,
              split.amount
            )
        );
      }
    }

    await env.expense_app_db.batch(statements);

    return response({
      id: expenseId,
      amount,
      paidById,
      paidForIds: uniquePaidForIds,
      groupId,
      dateTime,
      description,
      isEqualSplit,
      customSplits: isEqualSplit ? {} : customSplits.reduce(
        (result, split) => {
          result[split.userId] = split.amount;
          return result;
        },
        {} as Record<string, number>
      ),
    });
  } catch (error) {
    console.error("PUT /api/expenses/:expenseId ERROR:", error);

    return response(
      {
        error: "Failed to update expense",
        details: String(error),
      },
      500
    );
  }
}