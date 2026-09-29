export interface Env {
  expense_app_db: D1Database;
}

export type UserRow = {
  id: string;
  name: string;
  email: string | null;
  photo_url: string | null;
  account_number: string | null;
};