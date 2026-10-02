PRAGMA foreign_keys = ON;

-- =========================
-- Case-insensitive email lookup
-- register.ts now checks `WHERE LOWER(TRIM(email)) = ?` to catch legacy rows
-- stored with different case/whitespace (the "email already registered" bug).
-- This functional index keeps that lookup O(log n) instead of a full scan.
-- =========================

CREATE INDEX IF NOT EXISTS idx_users_email_normalized
ON users(LOWER(TRIM(email)))
WHERE email IS NOT NULL;
