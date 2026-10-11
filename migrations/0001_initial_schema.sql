
PRAGMA foreign_keys = ON;

-- BusinessOS initial database schema
-- Designed for Cloudflare D1 (SQLite)

CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL COLLATE NOCASE UNIQUE,
  display_name TEXT,
  auth_provider TEXT NOT NULL DEFAULT 'email',
  auth_subject TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  deleted_at TEXT
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_provider_subject
ON users(auth_provider, auth_subject)
WHERE auth_subject IS NOT NULL;

CREATE TABLE IF NOT EXISTS user_settings (
  user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  locale TEXT NOT NULL DEFAULT 'en-NG',
  timezone TEXT NOT NULL DEFAULT 'Africa/Lagos',
  currency TEXT NOT NULL DEFAULT 'NGN',
  preferences_json TEXT NOT NULL DEFAULT '{}',
  memory_enabled INTEGER NOT NULL DEFAULT 1
    CHECK (memory_enabled IN (0,1)),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS businesses (
  id TEXT PRIMARY KEY,
  owner_user_id TEXT NOT NULL REFERENCES users(id),
  name TEXT NOT NULL,
  business_type TEXT,
  description TEXT,
  currency TEXT NOT NULL DEFAULT 'NGN',
  timezone TEXT NOT NULL DEFAULT 'Africa/Lagos',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  archived_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_businesses_owner
ON businesses(owner_user_id, archived_at);

CREATE TABLE IF NOT EXISTS business_members (
  business_id TEXT NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'member'
    CHECK (role IN ('owner','admin','manager','staff','viewer')),
  joined_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (business_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_business_members_user
ON business_members(user_id);

CREATE TABLE IF NOT EXISTS customers (
  id TEXT PRIMARY KEY,
  business_id TEXT NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  phone TEXT,
  email TEXT,
  address TEXT,
  notes TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_customers_business
ON customers(business_id, name);

CREATE TABLE IF NOT EXISTS suppliers (
  id TEXT PRIMARY KEY,
  business_id TEXT NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  phone TEXT,
  email TEXT,
  address TEXT,
  notes TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_suppliers_business
ON suppliers(business_id, name);

CREATE TABLE IF NOT EXISTS products (
  id TEXT PRIMARY KEY,
  business_id TEXT NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  supplier_id TEXT REFERENCES suppliers(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  sku TEXT,
  barcode TEXT,
  description TEXT,
  category TEXT,
  unit TEXT NOT NULL DEFAULT 'item',
  cost_price_minor INTEGER NOT NULL DEFAULT 0 CHECK (cost_price_minor >= 0),
  selling_price_minor INTEGER NOT NULL DEFAULT 0 CHECK (selling_price_minor >= 0),
  stock_quantity REAL NOT NULL DEFAULT 0,
  low_stock_threshold REAL NOT NULL DEFAULT 0,
  track_inventory INTEGER NOT NULL DEFAULT 1
    CHECK (track_inventory IN (0,1)),
  image_asset_id TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  archived_at TEXT,
  UNIQUE (business_id, sku)
);

CREATE INDEX IF NOT EXISTS idx_products_business_name
ON products(business_id, name);

CREATE INDEX IF NOT EXISTS idx_products_barcode
ON products(business_id, barcode);

CREATE TABLE IF NOT EXISTS inventory_movements (
  id TEXT PRIMARY KEY,
  business_id TEXT NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  product_id TEXT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  movement_type TEXT NOT NULL
    CHECK (movement_type IN ('opening','purchase','sale','adjustment','return','damage')),
  quantity_delta REAL NOT NULL,
  unit_cost_minor INTEGER,
  reference_type TEXT,
  reference_id TEXT,
  note TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_inventory_product_time
ON inventory_movements(product_id, created_at);

CREATE TABLE IF NOT EXISTS sales (
  id TEXT PRIMARY KEY,
  business_id TEXT NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  customer_id TEXT REFERENCES customers(id) ON DELETE SET NULL,
  created_by_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  sale_number TEXT,
  status TEXT NOT NULL DEFAULT 'completed'
    CHECK (status IN ('draft','completed','cancelled','refunded')),
  subtotal_minor INTEGER NOT NULL DEFAULT 0,
  discount_minor INTEGER NOT NULL DEFAULT 0,
  tax_minor INTEGER NOT NULL DEFAULT 0,
  total_minor INTEGER NOT NULL DEFAULT 0,
  amount_paid_minor INTEGER NOT NULL DEFAULT 0,
  payment_method TEXT,
  notes TEXT,
  sold_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (business_id, sale_number)
);

CREATE INDEX IF NOT EXISTS idx_sales_business_date
ON sales(business_id, sold_at);

CREATE TABLE IF NOT EXISTS sale_items (
  id TEXT PRIMARY KEY,
  sale_id TEXT NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
  product_id TEXT REFERENCES products(id) ON DELETE SET NULL,
  product_name_snapshot TEXT NOT NULL,
  sku_snapshot TEXT,
  quantity REAL NOT NULL CHECK (quantity > 0),
  unit_price_minor INTEGER NOT NULL CHECK (unit_price_minor >= 0),
  unit_cost_minor INTEGER NOT NULL DEFAULT 0 CHECK (unit_cost_minor >= 0),
  line_total_minor INTEGER NOT NULL CHECK (line_total_minor >= 0)
);

CREATE INDEX IF NOT EXISTS idx_sale_items_sale
ON sale_items(sale_id);

CREATE TABLE IF NOT EXISTS expenses (
  id TEXT PRIMARY KEY,
  business_id TEXT NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  created_by_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  category TEXT NOT NULL DEFAULT 'other',
  description TEXT NOT NULL,
  amount_minor INTEGER NOT NULL CHECK (amount_minor >= 0),
  payment_method TEXT,
  receipt_asset_id TEXT,
  expense_date TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_expenses_business_date
ON expenses(business_id, expense_date);

CREATE TABLE IF NOT EXISTS ai_conversations (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  business_id TEXT REFERENCES businesses(id) ON DELETE SET NULL,
  title TEXT NOT NULL DEFAULT 'New conversation',
  conversation_type TEXT NOT NULL DEFAULT 'assistant',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  archived_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_ai_conversations_user
ON ai_conversations(user_id, updated_at);

CREATE TABLE IF NOT EXISTS ai_messages (
  id TEXT PRIMARY KEY,
  conversation_id TEXT NOT NULL REFERENCES ai_conversations(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('system','user','assistant','tool')),
  content TEXT NOT NULL,
  attachments_json TEXT NOT NULL DEFAULT '[]',
  metadata_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_ai_messages_conversation
ON ai_messages(conversation_id, created_at);

CREATE TABLE IF NOT EXISTS ai_memories (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  business_id TEXT REFERENCES businesses(id) ON DELETE CASCADE,
  memory_type TEXT NOT NULL DEFAULT 'fact',
  content TEXT NOT NULL,
  source_conversation_id TEXT REFERENCES ai_conversations(id) ON DELETE SET NULL,
  importance REAL NOT NULL DEFAULT 0.5
    CHECK (importance BETWEEN 0 AND 1),
  confidence REAL NOT NULL DEFAULT 0.8
    CHECK (confidence BETWEEN 0 AND 1),
  sensitivity TEXT NOT NULL DEFAULT 'normal'
    CHECK (sensitivity IN ('normal','sensitive')),
  user_confirmed INTEGER NOT NULL DEFAULT 0
    CHECK (user_confirmed IN (0,1)),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at TEXT,
  deleted_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_ai_memories_user
ON ai_memories(user_id, deleted_at, importance);

CREATE INDEX IF NOT EXISTS idx_ai_memories_business
ON ai_memories(business_id, deleted_at);

CREATE TABLE IF NOT EXISTS media_assets (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  business_id TEXT REFERENCES businesses(id) ON DELETE CASCADE,
  storage_key TEXT NOT NULL UNIQUE,
  media_type TEXT NOT NULL
    CHECK (media_type IN ('product_image','receipt','document','other')),
  mime_type TEXT NOT NULL,
  size_bytes INTEGER NOT NULL CHECK (size_bytes >= 0),
  original_filename TEXT,
  processing_status TEXT NOT NULL DEFAULT 'uploaded'
    CHECK (processing_status IN ('uploaded','processing','processed','failed')),
  extracted_text TEXT,
  ai_result_json TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  deleted_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_media_assets_business
ON media_assets(business_id, created_at);

CREATE TABLE IF NOT EXISTS subscriptions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  plan_key TEXT NOT NULL CHECK (plan_key IN ('free','pro','team')),
  billing_provider TEXT,
  provider_customer_id TEXT,
  provider_subscription_id TEXT UNIQUE,
  status TEXT NOT NULL DEFAULT 'inactive'
    CHECK (status IN ('trialing','active','past_due','cancelled','inactive')),
  current_period_start TEXT,
  current_period_end TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_subscriptions_user_status
ON subscriptions(user_id, status);

CREATE TABLE IF NOT EXISTS audit_events (
  id TEXT PRIMARY KEY,
  business_id TEXT REFERENCES businesses(id) ON DELETE CASCADE,
  actor_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT,
  metadata_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_audit_business_time
ON audit_events(business_id, created_at);
  
