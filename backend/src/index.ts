import { Env } from "./types";
import { response, corsHeaders } from "./utils/response";
import { handleGetUser } from "./users/getUser";
import { handleGetFriends } from "./friends/getFriends";
import { handleAddFriend } from "./friends/addFriend";
import { handleRemoveFriend } from "./friends/removeFriend";
import { handleCreateGroup } from "./groups/createGroup";
import { handleGetGroup } from "./groups/getGroup";
import { handleUpdateGroup } from "./groups/updateGroup";
import { handleDeleteGroup } from "./groups/deleteGroup";
import { handleAddMember } from "./groups/addMember";
import { handleRemoveMember } from "./groups/removeMember";
import { handleCreateExpense } from "./expenses/createExpense";
import { handleGetExpense } from "./expenses/getExpense";
import { handleUpdateExpense } from "./expenses/updateExpense";
import { handleDeleteExpense } from "./expenses/deleteExpense";
import { handleCheckDisplayName } from "./displayNames/checkDisplayName";
import { handleSaveDisplayName } from "./displayNames/saveDisplayName";
import { handleRegister } from "./auth/register";
import { handleLogin } from "./auth/login";
import { handleRefresh, handleLogout } from "./auth/refresh";
import { handleGoogleLogin } from "./auth/google";
import { handleForgotPassword, handleResetPassword } from "./auth/passwordReset";
import { authenticate } from "./auth/middleware";
import { handleGetMyGroups } from "./me/getGroups";
import { handleGetMyExpenses } from "./me/getExpenses";
import { handleGetContacts } from "./me/getContacts";
import { handleBootstrap } from "./me/bootstrap";
import { handleUpdateMe } from "./me/updateMe";
import { handleSearchUsers } from "./users/searchUsers";
import { handleGetGroupExpenses } from "./groups/getExpenses";

// مسیرهایی که بدون توکن در دسترس‌اند. بقیه‌ی /api/* نیاز به ورود دارند.
const PUBLIC_ROUTES = new Set([
  "POST /api/auth/register",
  "POST /api/auth/login",
  "POST /api/auth/refresh",
  "POST /api/auth/logout",
  "POST /api/auth/google",
  "POST /api/auth/password/forgot",
  "POST /api/auth/password/reset",
  "GET /api/display-names/check",
]);

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // مدیریت درخواست‌های OPTIONS برای CORS
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders() });
    }

    const url = new URL(request.url);
    const path = url.pathname;

    try {
      // بررسی سلامت سرویس (Health check)
      if (request.method === "GET" && path === "/") {
        return response({ message: "Expense App API is running" });
      }

      // همه‌ی مسیرهای /api/* به‌جز PUBLIC_ROUTES نیاز به توکن معتبر دارند
      if (path.startsWith("/api/") && !PUBLIC_ROUTES.has(`${request.method} ${path}`)) {
        const auth = await authenticate(request, env);
        if (auth instanceof Response) return auth;
        // auth همان userId است؛ در گام ۲ برای چک دسترسی استفاده می‌شود
      }

      // ---- مسیرهای کاربر واردشده (/api/me/*) ----
      // همه‌ی داده‌های اولیه در یک درخواست: GET /api/me/bootstrap
      if (request.method === "GET" && path === "/api/me/bootstrap") {
        return handleBootstrap(request, env);
      }

      // لیست گروه‌های کاربر واردشده: GET /api/me/groups
      if (request.method === "GET" && path === "/api/me/groups") {
        return handleGetMyGroups(request, env);
      }

      // هزینه‌های همه‌ی گروه‌های کاربر: GET /api/me/expenses
      if (request.method === "GET" && path === "/api/me/expenses") {
        return handleGetMyExpenses(request, env);
      }

      // کاربران قابل مشاهده (خود، دوستان، هم‌گروهی‌ها): GET /api/me/contacts
      if (request.method === "GET" && path === "/api/me/contacts") {
        return handleGetContacts(request, env);
      }

      // ویرایش پروفایل خودِ کاربر: PUT /api/me
      if (request.method === "PUT" && path === "/api/me") {
        return handleUpdateMe(request, env);
      }

      // جست‌وجوی کاربران: GET /api/users/search?q=...
      // ⚠️ باید قبل از الگوی /api/users/:userId بیاید، وگرنه "search" به‌عنوان
      // userId تفسیر می‌شود.
      if (request.method === "GET" && path === "/api/users/search") {
        return handleSearchUsers(request, env);
      }

      // لیست هزینه‌های یک گروه: GET /api/groups/:groupId/expenses
      const groupExpensesMatch = path.match(/^\/api\/groups\/([^/]+)\/expenses$/);
      if (request.method === "GET" && groupExpensesMatch) {
        return handleGetGroupExpenses(request, env, groupExpensesMatch[1]);
      }

      // دریافت کاربر: GET /api/users/:userId
      const getUserMatch = path.match(/^\/api\/users\/([^/]+)$/);
      if (request.method === "GET" && getUserMatch) {
        return handleGetUser(request, env, getUserMatch[1]);
      }

      // دریافت دوستان: GET /api/users/:userId/friends
      const getFriendsMatch = path.match(/^\/api\/users\/([^/]+)\/friends$/);
      if (request.method === "GET" && getFriendsMatch) {
        return handleGetFriends(request, env, getFriendsMatch[1]);
      }

      // افزودن دوست: POST /api/users/:userId/friends
      if (request.method === "POST" && getFriendsMatch) {
        return handleAddFriend(request, env, getFriendsMatch[1]);
      }

      // حذف دوست: DELETE /api/users/:userId/friends/:friendId
      const removeFriendMatch = path.match(/^\/api\/users\/([^/]+)\/friends\/([^/]+)$/);
      if (request.method === "DELETE" && removeFriendMatch) {
        return handleRemoveFriend(request, env, removeFriendMatch[1], removeFriendMatch[2]);
      }

	  // افزودن عضو: POST /api/groups/:groupId/members
const addMemberMatch = path.match(
  /^\/api\/groups\/([^/]+)\/members$/
);

if (request.method === "POST" && addMemberMatch) {
  return handleAddMember(
    request,
    env,
    addMemberMatch[1]
  );
}

// حذف عضو: DELETE /api/groups/:groupId/members/:userId
const removeMemberMatch = path.match(
  /^\/api\/groups\/([^/]+)\/members\/([^/]+)$/
);

if (request.method === "DELETE" && removeMemberMatch) {
  return handleRemoveMember(
    request,
    env,
    removeMemberMatch[1],
    removeMemberMatch[2]
  );
}

	  // دریافت گروه: GET /api/groups/:groupId
const getGroupMatch = path.match(/^\/api\/groups\/([^/]+)$/);

if (request.method === "GET" && getGroupMatch) {
  return handleGetGroup(request, env, getGroupMatch[1]);
}

	  // ایجاد گروه: POST /api/groups
if (request.method === "POST" && path === "/api/groups") {
  return handleCreateGroup(request, env);
}

// به‌روزرسانی گروه: PUT /api/groups/:groupId
if (request.method === "PUT" && getGroupMatch) {
  return handleUpdateGroup(request, env, getGroupMatch[1]);
}

// حذف گروه: DELETE /api/groups/:groupId
if (request.method === "DELETE" && getGroupMatch) {
  return handleDeleteGroup(request, env, getGroupMatch[1]);
}

// ایجاد Expense: POST /api/expenses
if (request.method === "POST" && path === "/api/expenses") {
  return handleCreateExpense(request, env);
}

const getExpenseMatch = path.match(/^\/api\/expenses\/([^/]+)$/);

if (request.method === "GET" && getExpenseMatch) {
  return handleGetExpense(
    request,
    env,
    getExpenseMatch[1]
  );
}

if (request.method === "PUT" && getExpenseMatch) {
  return handleUpdateExpense(
    request,
    env,
    getExpenseMatch[1]
  );
}

if (request.method === "DELETE" && getExpenseMatch) {
  return handleDeleteExpense(
    request,
    env,
    getExpenseMatch[1]
  );
}

const displayNameCheckPath = path === "/api/display-names/check";

if (request.method === "GET" && displayNameCheckPath) {
  return handleCheckDisplayName(request, env);
}

if (request.method === "POST" && path === "/api/display-names") {
  return handleSaveDisplayName(request, env);
}

if (request.method === "POST" && path === "/api/auth/register") {
  return handleRegister(request, env);
}
if (request.method === "POST" && path === "/api/auth/login") {
  return handleLogin(request, env);
}
if (request.method === "POST" && path === "/api/auth/refresh") {
  return handleRefresh(request, env);
}
if (request.method === "POST" && path === "/api/auth/logout") {
  return handleLogout(request, env);
}
if (request.method === "POST" && path === "/api/auth/google") {
  return handleGoogleLogin(request, env);
}
if (request.method === "POST" && path === "/api/auth/password/forgot") {
  return handleForgotPassword(request, env);
}
if (request.method === "POST" && path === "/api/auth/password/reset") {
  return handleResetPassword(request, env);
}
      // مسیر یافت نشد
      return response({ error: "Route not found" }, 404);
    } catch (error) {
      console.error("Internal Server Error:", error);
      return response({ error: "Internal server error" }, 500);
    }
  },
};