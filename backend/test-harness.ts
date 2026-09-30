import { createHmac, randomUUID, createHash } from "node:crypto";
import type { Env } from "./src/types";
import { handleRegister } from "./src/auth/register";
import { handleLogin } from "./src/auth/login";
import { handleCreateGroup } from "./src/groups/createGroup";
import { handleGetGroup } from "./src/groups/getGroup";
import { handleAddMember } from "./src/groups/addMember";
import { handleCreateExpense } from "./src/expenses/createExpense";
import { handleGetExpense } from "./src/expenses/getExpense";
import { handleUpdateExpense } from "./src/expenses/updateExpense";
import { handleDeleteExpense } from "./src/expenses/deleteExpense";

// ---------- fake D1 (SQLite-ish, only what these handlers need) ----------
type Row = Record<string, any>;
const db: Record<string, Row[]> = {
  users: [], auth_credentials: [], refresh_tokens: [], groups: [], display_names: [],
  group_members: [], expenses: [], expense_participants: [], expense_splits: [],
};
function norm(s: string) { return s.replace(/\s+/g, " ").trim().toLowerCase(); }

function makeStmt(sql: string) {
  // bindings per-statement (batch() runs several statements at once)
  let bindings: any[] = [];
  const run = () => {
    const n = norm(sql);
    if (process.env.HARNESS_DEBUG) console.error("[W]", n.slice(0, 90), JSON.stringify(bindings));
    if (n.startsWith("insert into users")) {
      db.users.push({ id: bindings[0], name: bindings[1], email: bindings[2] ?? null,
        photo_url: null, account_number: null,
        created_at: bindings[3], updated_at: bindings[4] });
    } else if (n.startsWith("insert into auth_credentials")) {
      db.auth_credentials.push({ user_id: bindings[0], password_hash: bindings[1],
        email_verified: 0, created_at: bindings[2] });
    } else if (n.startsWith("insert into refresh_tokens")) {
      db.refresh_tokens.push({ token_hash: bindings[0], user_id: bindings[1],
        expires_at: bindings[2], created_at: bindings[3] });
    } else if (n.startsWith("insert into groups")) {
      db.groups.push({ id: bindings[0], name: bindings[1], created_by: bindings[2],
        created_at: bindings[3], updated_at: bindings[4] });
    } else if (n.startsWith("insert into group_members")) {
      db.group_members.push({ group_id: bindings[0], user_id: bindings[1] });
    } else if (n.startsWith("insert into expenses")) {
      db.expenses.push({ id: bindings[0], group_id: bindings[1], amount: bindings[2],
        paid_by_id: bindings[3], date_time: bindings[4], description: bindings[5],
        is_equal_split: bindings[6], created_at: bindings[7], updated_at: bindings[8] });
    } else if (n.startsWith("insert into expense_participants")) {
      db.expense_participants.push({ expense_id: bindings[0], user_id: bindings[1] });
    } else if (n.startsWith("insert into expense_splits")) {
      db.expense_splits.push({ expense_id: bindings[0], user_id: bindings[1], amount: bindings[2] });
    } else if (n.startsWith("insert into display_names")) {
      db.display_names.push({ display_name_lower: bindings[0], display_name: bindings[1], created_at: bindings[2] });
    } else if (n.startsWith("delete from")) {
      const table = n.split(" ")[2];
      if (table === "expenses") db.expenses = db.expenses.filter(r => r.id !== bindings[0]);
      else if (table === "expense_participants") db.expense_participants = db.expense_participants.filter(r => r.expense_id !== bindings[0]);
      else if (table === "expense_splits") db.expense_splits = db.expense_splits.filter(r => r.expense_id !== bindings[0]);
      else if (table === "refresh_tokens") db.refresh_tokens = db.refresh_tokens.filter(r => r.token_hash !== bindings[0]);
    } else if (n.startsWith("update expenses")) {
      const e = db.expenses.find(r => r.id === bindings[bindings.length - 1]);
      if (e) { e.group_id = bindings[0]; e.amount = bindings[1]; e.paid_by_id = bindings[2];
        e.date_time = bindings[3]; e.description = bindings[4]; e.is_equal_split = bindings[5]; e.updated_at = bindings[6]; }
    } else throw new Error("unhandled write SQL: " + sql);
    return { success: true, meta: { changes: 1 } };
  };
  const exec = () => {
    const n = norm(sql);
    if (process.env.HARNESS_DEBUG) console.error("[R]", n.slice(0, 90), JSON.stringify(bindings));
    let rows: Row[] = [];
    if (n.includes("left join auth_credentials")) {
      const u = db.users.find(r => r.email === bindings[0]);
      if (!u) return [];
      const c = db.auth_credentials.find(r => r.user_id === u.id);
      rows = [{ ...u, password_hash: c?.password_hash ?? null }];
    }
    else if (n.includes("from users where email = ?")) rows = db.users.filter(r => r.email === bindings[0]);
    else if (n.includes("from users where id in (")) rows = db.users.filter(r => bindings.includes(r.id));
    else if (n.includes("from users") && n.includes("where id = ?")) rows = db.users.filter(r => r.id === bindings[0]);
    else if (n.includes("from auth_credentials") && n.includes("where user_id = ?")) rows = db.auth_credentials.filter(r => r.user_id === bindings[0]);
    else if (n.includes("from display_names")) rows = db.display_names.filter(r => r.display_name_lower === bindings[0]);
    else if (n.includes("from groups") && n.includes("where id = ?")) rows = db.groups.filter(r => r.id === bindings[0]);
    else if (n.includes("from group_members") && n.includes("group_id = ? and user_id = ?")) rows = db.group_members.filter(r => r.group_id === bindings[0] && r.user_id === bindings[1]);
    else if (n.includes("from group_members") && n.includes("where group_id = ?")) rows = db.group_members.filter(r => r.group_id === bindings[0]);
    else if (n.includes("from expenses") && n.includes("where id = ?")) rows = db.expenses.filter(r => r.id === bindings[0]);
    else if (n.includes("from expenses") && n.includes("where group_id = ?")) rows = db.expenses.filter(r => r.group_id === bindings[0]).map(e => ({ id: e.id }));
    else if (n.includes("from expense_participants")) rows = db.expense_participants.filter(r => r.expense_id === bindings[0]);
    else if (n.includes("from expense_splits")) rows = db.expense_splits.filter(r => r.expense_id === bindings[0]);
    else if (n.includes("from refresh_tokens")) rows = db.refresh_tokens.filter(r => r.token_hash === bindings[0]);
    else if (n.includes("from friendships")) rows = [];
    else if (n.includes("count(")) rows = [{ c: 0 }];
    else throw new Error("unhandled read SQL: " + sql);
    return rows;
  };
  const self = {
    bind(...b: any[]) { bindings = b; return self; },
    async first<T>() { const r = exec(); return (r[0] as T) ?? null; },
    async all<T>() { return { results: exec() as T[] }; },
    async run() { return run(); },
  };
  return self;
}

const env = {
  expense_app_db: {
    prepare(sql: string) { return makeStmt(sql); },
    async batch(statements: any[]) {
      // D1 batch accepts prepared statements OR plain {sql, bindings} objects
      for (const st of statements) {
        if (typeof st.run === "function") await st.run();
        else { const p = this.prepare(st.sql); p.bind(...(st.bindings ?? [])); await p.run(); }
      }
      return [];
    },
  },
  JWT_SECRET: "test-secret-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  PASSWORD_PEPPER: "test-pepper-bbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  GOOGLE_CLIENT_ID: "fake.apps.googleusercontent.com",
} as unknown as Env;

const nodeCrypto = require("node:crypto");
const realSubtle = globalThis.crypto.subtle;
const origImportKey = realSubtle.importKey.bind(realSubtle);
const origDeriveBits = realSubtle.deriveBits.bind(realSubtle);
const origSign = realSubtle.sign.bind(realSubtle);
const origVerify = realSubtle.verify.bind(realSubtle);
const origDigest = realSubtle.digest.bind(realSubtle);

(globalThis.crypto as any).subtle = {
  digest: (alg: string, data: ArrayBuffer) => origDigest(alg, data),
  async importKey(fmt: string, secret: any, alg: any, usable: boolean, ops: string[]) {
    if (typeof alg === "object" && alg.name === "PBKDF2") {
      return { __pw: Buffer.from(new Uint8Array(secret)) };
    }
    return origImportKey(fmt, secret, alg, usable, ops);
  },
  async deriveBits(algo: any, key: any, bits: number) {
    if (key && key.__pw) {
      const out = nodeCrypto.pbkdf2Sync(key.__pw, Buffer.from(algo.salt), algo.iterations, bits / 8, "sha512");
      return out.buffer.slice(out.byteOffset, out.byteOffset + out.byteLength);
    }
    return origDeriveBits(algo, key, bits);
  },
  sign(alg: any, key: any, data: ArrayBuffer) { return origSign(alg, key, data); },
  verify(alg: any, key: any, sig: ArrayBuffer, data: ArrayBuffer) { return origVerify(alg, key, sig, data); },
};

// ---------- helpers ----------
function req(method: string, url: string, body?: any, token?: string) {
  const headers: Record<string, string> = {};
  if (token) headers.Authorization = "Bearer " + token;
  return new Request("http://x" + url, { method, headers, body: body ? JSON.stringify(body) : undefined });
}
let pass = 0, fail = 0;
function check(name: string, cond: boolean, extra?: any) {
  if (cond) { pass++; console.log("PASS " + name); }
  else { fail++; console.log("FAIL " + name, extra !== undefined ? JSON.stringify(extra) : ""); }
}

async function main() {
  if (process.env.HARNESS_DEBUG) {
    const mw = await import("./src/auth/middleware");
    const orig = mw.authenticate;
    (mw as any).authenticate = async (request: Request, env2: Env) => {
      const r = await orig(request, env2);
      console.error("[AUTH]", request.method, request.url, "->", typeof r === "string" ? r : "Response " + r.status);
      return r;
    };
  }
  // register two users
  let res = await handleRegister(req("POST", "/api/auth/register", { name: "Ali", email: "ali@test.com", password: "password123" }), env);
  check("register ali 201", res.status === 201, await res.clone().json());
  const ali = await res.json<any>();
  res = await handleRegister(req("POST", "/api/auth/register", { name: "Reza", email: "reza@test.com", password: "password456" }), env);
  const reza = await res.json<any>();
  check("register reza 201", res.status === 201);
  res = await handleLogin(req("POST", "/api/auth/login", { email: "ali@test.com", password: "password123" }), env);
  const aliLogin = await res.json<any>();
  check("login ok", res.status === 200 && !!aliLogin.accessToken);
  res = await handleLogin(req("POST", "/api/auth/login", { email: "ali@test.com", password: "wrongpass" }), env);
  check("login wrong password 401", res.status === 401);

  // ali creates group
  const groupId = randomUUID();
res = await handleCreateGroup(req("POST", "/api/groups", { id: groupId, name: "Trip" }, aliLogin.accessToken), env);
  check("create group 201", res.status === 201, await res.clone().json());
  await res.json<any>();

  // reza adds himself to group (allowed by design) then creates expense
  // third user outsider
  res = await handleRegister(req("POST", "/api/auth/register", { name: "Out", email: "out@test.com", password: "password789" }), env);
  const out = await res.json<any>();
  res = await handleLogin(req("POST", "/api/auth/login", { email: "out@test.com", password: "password789" }), env);
  const outTok = (await res.json<any>()).accessToken;

    res = await handleAddMember(req("POST", `/api/groups/${groupId}/members`, { userId: reza.id }, aliLogin.accessToken), env, groupId);
  check("ali adds reza 201", res.status === 201, await res.clone().json());
  res = await handleAddMember(req("POST", `/api/groups/${groupId}/members`, { userId: out.id }, reza.accessToken), env, groupId);
  check("non-creator addMember 403", res.status === 403, res.status);

  // outsider cannot see group
  res = await handleGetGroup(req("GET", `/api/groups/${groupId}`, undefined, outTok), env, groupId);
  check("outsider GET group 403", res.status === 403, res.status);
  // member can see group
  res = await handleGetGroup(req("GET", `/api/groups/${groupId}`, undefined, reza.accessToken), env, groupId);
  check("member GET group 200", res.status === 200);

  // ali creates expense with both participants
  const expenseId = randomUUID();
  res = await handleCreateExpense(req("POST", "/api/expenses", {
    id: expenseId, amount: 100, paidForIds: [ali.id, reza.id], groupId, dateTime: new Date().toISOString(),
    description: "dinner", isEqualSplit: true,
  }, aliLogin.accessToken), env);
  check("create expense 201", res.status === 201, await res.clone().json());
  await res.json<any>();

  // outsider cannot get expense
  res = await handleGetExpense(req("GET", `/api/expenses/${expenseId}`, undefined, outTok), env, expenseId);
  check("outsider GET expense 403", res.status === 403, res.status);
  // member can get expense
  res = await handleGetExpense(req("GET", `/api/expenses/${expenseId}`, undefined, reza.accessToken), env, expenseId);
  check("member GET expense 200", res.status === 200);

  // outsider cannot update expense
  res = await handleUpdateExpense(req("PUT", `/api/expenses/${expenseId}`, { description: "hacked" }, outTok), env, expenseId);
  check("outsider PUT expense 403", res.status === 403, res.status);
  // member can update expense
  res = await handleUpdateExpense(req("PUT", `/api/expenses/${expenseId}`, { description: "lunch" }, reza.accessToken), env, expenseId);
  check("member PUT expense 200", res.status === 200, await res.clone().json());
  // update to move to nonexistent group must fail
  res = await handleUpdateExpense(req("PUT", `/api/expenses/${expenseId}`, { groupId: "no-such-group" }, reza.accessToken), env, expenseId);
  check("PUT expense bad group 404/400", res.status === 404 || res.status === 400, res.status);

  // outsider cannot delete expense
  res = await handleDeleteExpense(req("DELETE", `/api/expenses/${expenseId}`, undefined, outTok), env, expenseId);
  check("outsider DELETE expense 403", res.status === 403, res.status);
  // no token at all
  res = await handleDeleteExpense(req("DELETE", `/api/expenses/${expenseId}`), env, expenseId);
  check("no-token DELETE expense 401", res.status === 401, res.status);
  // member deletes
  res = await handleDeleteExpense(req("DELETE", `/api/expenses/${expenseId}`, undefined, reza.accessToken), env, expenseId);
  check("member DELETE expense 200", res.status === 200, await res.clone().json());
  // deleting again -> 404
  res = await handleDeleteExpense(req("DELETE", `/api/expenses/${expenseId}`, undefined, reza.accessToken), env, expenseId);
  check("deleted expense 404", res.status === 404, res.status);

  // tampered token
  res = await handleGetGroup(req("GET", `/api/groups/${groupId}`, undefined, aliLogin.accessToken + "xx"), env, groupId);
  check("tampered token 401", res.status === 401);

  console.log(`\nRESULT: ${pass} passed, ${fail} failed`);
  process.exit(fail ? 1 : 0);
}
main().catch(e => { console.error("HARNESS ERROR:", e); process.exit(2); });
