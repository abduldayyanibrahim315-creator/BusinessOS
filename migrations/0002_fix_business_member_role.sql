

-- Fix the default role while preserving existing memberships.

CREATE TABLE business_members_new (
  business_id TEXT NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'staff'
    CHECK (role IN ('owner','admin','manager','staff','viewer')),
  joined_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (business_id, user_id)
);

INSERT INTO business_members_new
  (business_id, user_id, role, joined_at)
SELECT business_id, user_id, role, joined_at
FROM business_members;

DROP TABLE business_members;

ALTER TABLE business_members_new
RENAME TO business_members;

CREATE INDEX IF NOT EXISTS idx_business_members_user
ON business_members(user_id);
