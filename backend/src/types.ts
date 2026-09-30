export interface Env {
  expense_app_db: D1Database;

  // vars (wrangler.jsonc)
  GOOGLE_CLIENT_ID: string;
  PBKDF2_ITERATIONS?: string;

  // secrets (wrangler secret put / .dev.vars)
  JWT_SECRET: string;
  PASSWORD_PEPPER: string;
}

export type UserRow = {
  id: string;
  name: string;
  email: string | null;
  photo_url: string | null;
  account_number: string | null;
};

// نتیجه‌ی authenticate(): یا userId و یا یک Response آماده (۴۰۱) برای برگرداندن.
export type AuthResult = string | Response;