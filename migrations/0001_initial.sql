PRAGMA foreign_keys = ON;

CREATE TABLE users (
  id TEXT PRIMARY KEY NOT NULL,
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('admin', 'customer')),
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE ticket_categories (
  id TEXT PRIMARY KEY NOT NULL,
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
  created_at TEXT NOT NULL
);

CREATE TABLE tickets (
  id TEXT PRIMARY KEY NOT NULL,
  customer_id TEXT NOT NULL,
  category_id TEXT,
  subject TEXT NOT NULL,
  description TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'in_progress', 'resolved', 'closed')),
  priority TEXT NOT NULL DEFAULT 'normal'
    CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
  metadata TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (customer_id) REFERENCES users (id) ON DELETE RESTRICT,
  FOREIGN KEY (category_id) REFERENCES ticket_categories (id) ON DELETE SET NULL
);

CREATE TABLE ticket_messages (
  id TEXT PRIMARY KEY NOT NULL,
  ticket_id TEXT NOT NULL,
  author_id TEXT NOT NULL,
  message TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (ticket_id) REFERENCES tickets (id) ON DELETE CASCADE,
  FOREIGN KEY (author_id) REFERENCES users (id) ON DELETE RESTRICT
);

CREATE TABLE ticket_attachments (
  id TEXT PRIMARY KEY NOT NULL,
  ticket_id TEXT NOT NULL,
  message_id TEXT,
  uploaded_by TEXT NOT NULL,
  object_key TEXT NOT NULL UNIQUE,
  original_name TEXT NOT NULL,
  mime_type TEXT NOT NULL,
  size_bytes INTEGER NOT NULL CHECK (size_bytes > 0),
  created_at TEXT NOT NULL,
  FOREIGN KEY (ticket_id) REFERENCES tickets (id) ON DELETE CASCADE,
  FOREIGN KEY (message_id) REFERENCES ticket_messages (id) ON DELETE SET NULL,
  FOREIGN KEY (uploaded_by) REFERENCES users (id) ON DELETE RESTRICT
);

CREATE TABLE sessions (
  id TEXT PRIMARY KEY NOT NULL,
  user_id TEXT NOT NULL,
  token_hash TEXT NOT NULL UNIQUE,
  expires_at TEXT NOT NULL,
  created_at TEXT NOT NULL,
  revoked_at TEXT,
  FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
);

CREATE INDEX idx_tickets_customer_id ON tickets (customer_id);
CREATE INDEX idx_tickets_category_id ON tickets (category_id);
CREATE INDEX idx_tickets_status ON tickets (status);
CREATE INDEX idx_ticket_messages_ticket_id ON ticket_messages (ticket_id);
CREATE INDEX idx_ticket_messages_author_id ON ticket_messages (author_id);
CREATE INDEX idx_ticket_attachments_ticket_id ON ticket_attachments (ticket_id);
CREATE INDEX idx_ticket_attachments_message_id ON ticket_attachments (message_id);
CREATE INDEX idx_ticket_attachments_uploaded_by ON ticket_attachments (uploaded_by);
CREATE INDEX idx_sessions_user_id ON sessions (user_id);
CREATE INDEX idx_sessions_expires_at ON sessions (expires_at);
