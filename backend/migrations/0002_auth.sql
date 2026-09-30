PRAGMA foreign_keys = ON;

-- =========================
-- Password credentials
-- (users who sign in only with Google have no row here)
-- =========================

CREATE TABLE auth_credentials (
    user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    password_hash TEXT NOT NULL,          -- pbkdf2$iterations$salt$hash
    email_verified INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL
);

-- =========================
-- Refresh tokens (only the SHA-256 hash is stored)
-- =========================

CREATE TABLE refresh_tokens (
    token_hash TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expires_at TEXT NOT NULL,
    created_at TEXT NOT NULL
);

CREATE INDEX idx_refresh_tokens_user ON refresh_tokens(user_id);

-- =========================
-- Password reset tokens (one-time, hash only)
-- =========================

CREATE TABLE password_resets (
    token_hash TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expires_at TEXT NOT NULL,
    created_at TEXT NOT NULL
);

CREATE INDEX idx_password_resets_user ON password_resets(user_id);
