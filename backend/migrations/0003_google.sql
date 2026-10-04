PRAGMA foreign_keys = ON;

-- =========================
-- Google identities
-- یک کاربر می‌تواند چند شناسه‌ی گوگل داشته باشد (مثلاً ایمیل شخصی + کاری).
-- ستون‌های users تغییر نمی‌کنند؛ فقط جدول جدید اضافه می‌شود.
-- =========================

CREATE TABLE google_identities (
    sub TEXT NOT NULL,                    -- subject claim از توکن گوگل (شناسه‌ی یکتای حساب)
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    email TEXT,                           -- ایمیلی که گوگل در آن لحظه گزارش داده
    created_at TEXT NOT NULL,

    PRIMARY KEY (sub)
);

CREATE INDEX idx_google_identities_user ON google_identities(user_id);
