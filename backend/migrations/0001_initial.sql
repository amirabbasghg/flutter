PRAGMA foreign_keys = ON;

-- =========================
-- Users
-- =========================

CREATE TABLE users (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT,
    photo_url TEXT,
    account_number TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE UNIQUE INDEX idx_users_email
ON users(email)
WHERE email IS NOT NULL;


-- =========================
-- Display Names
-- =========================

CREATE TABLE display_names (
    display_name_lower TEXT PRIMARY KEY,
    display_name TEXT NOT NULL,
    created_at TEXT NOT NULL
);


-- =========================
-- Friendships
-- =========================

CREATE TABLE friendships (
    user_id TEXT NOT NULL,
    friend_id TEXT NOT NULL,
    created_at TEXT NOT NULL,

    PRIMARY KEY (user_id, friend_id),

    FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE CASCADE,

    FOREIGN KEY (friend_id)
        REFERENCES users(id)
        ON DELETE CASCADE,

    CHECK (user_id != friend_id)
);


-- =========================
-- Groups
-- =========================

CREATE TABLE groups (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    created_by TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,

    FOREIGN KEY (created_by)
        REFERENCES users(id)
);


-- =========================
-- Group Members
-- =========================

CREATE TABLE group_members (
    group_id TEXT NOT NULL,
    user_id TEXT NOT NULL,

    PRIMARY KEY (group_id, user_id),

    FOREIGN KEY (group_id)
        REFERENCES groups(id)
        ON DELETE CASCADE,

    FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE CASCADE
);


-- =========================
-- Expenses
-- =========================

CREATE TABLE expenses (
    id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL,
    amount REAL NOT NULL,
    paid_by_id TEXT NOT NULL,
    date_time TEXT NOT NULL,
    description TEXT NOT NULL,
    is_equal_split INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,

    CHECK (is_equal_split IN (0, 1)),

    FOREIGN KEY (group_id)
        REFERENCES groups(id)
        ON DELETE CASCADE,

    FOREIGN KEY (paid_by_id)
        REFERENCES users(id)
);


-- =========================
-- Expense Participants
-- =========================

CREATE TABLE expense_participants (
    expense_id TEXT NOT NULL,
    user_id TEXT NOT NULL,

    PRIMARY KEY (expense_id, user_id),

    FOREIGN KEY (expense_id)
        REFERENCES expenses(id)
        ON DELETE CASCADE,

    FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE CASCADE
);


-- =========================
-- Custom Expense Splits
-- =========================

CREATE TABLE expense_splits (
    expense_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    amount REAL NOT NULL,

    PRIMARY KEY (expense_id, user_id),

    FOREIGN KEY (expense_id)
        REFERENCES expenses(id)
        ON DELETE CASCADE,

    FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE CASCADE
);


-- =========================
-- Indexes
-- =========================

CREATE INDEX idx_group_members_user
ON group_members(user_id);

CREATE INDEX idx_groups_created_by
ON groups(created_by);

CREATE INDEX idx_expenses_group
ON expenses(group_id);

CREATE INDEX idx_expenses_paid_by
ON expenses(paid_by_id);

CREATE INDEX idx_expense_participants_user
ON expense_participants(user_id);

CREATE INDEX idx_expense_splits_user
ON expense_splits(user_id);