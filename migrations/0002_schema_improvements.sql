-- Normalize persisted emails before enforcing case-insensitive uniqueness.
UPDATE users
SET email = LOWER(TRIM(email))
WHERE email <> LOWER(TRIM(email));

CREATE UNIQUE INDEX idx_users_email_nocase ON users (email COLLATE NOCASE);

-- Rebuild ticket_messages to add a creation timestamp default.
DROP INDEX idx_ticket_messages_ticket_id;
DROP INDEX idx_ticket_messages_author_id;

ALTER TABLE ticket_messages RENAME TO ticket_messages_old;

CREATE TABLE ticket_messages (
  id TEXT PRIMARY KEY NOT NULL,
  ticket_id TEXT NOT NULL,
  author_id TEXT NOT NULL,
  message TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (ticket_id) REFERENCES tickets (id) ON DELETE CASCADE,
  FOREIGN KEY (author_id) REFERENCES users (id) ON DELETE RESTRICT
);

INSERT INTO ticket_messages (id, ticket_id, author_id, message, created_at)
SELECT id, ticket_id, author_id, message, created_at
FROM ticket_messages_old;

CREATE INDEX idx_ticket_messages_ticket_id ON ticket_messages (ticket_id);
CREATE INDEX idx_ticket_messages_author_id ON ticket_messages (author_id);
CREATE UNIQUE INDEX idx_ticket_messages_ticket_id_id
ON ticket_messages (ticket_id, id);

-- Rebuild ticket_attachments to enforce ticket/message consistency and
-- add a creation timestamp default.
DROP INDEX idx_ticket_attachments_ticket_id;
DROP INDEX idx_ticket_attachments_message_id;
DROP INDEX idx_ticket_attachments_uploaded_by;

ALTER TABLE ticket_attachments RENAME TO ticket_attachments_old;

CREATE TABLE ticket_attachments (
  id TEXT PRIMARY KEY NOT NULL,
  ticket_id TEXT NOT NULL,
  message_id TEXT,
  uploaded_by TEXT NOT NULL,
  object_key TEXT NOT NULL UNIQUE,
  original_name TEXT NOT NULL,
  mime_type TEXT NOT NULL,
  size_bytes INTEGER NOT NULL CHECK (size_bytes > 0),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (ticket_id) REFERENCES tickets (id) ON DELETE CASCADE,
  FOREIGN KEY (ticket_id, message_id)
    REFERENCES ticket_messages (ticket_id, id) ON DELETE CASCADE,
  FOREIGN KEY (uploaded_by) REFERENCES users (id) ON DELETE RESTRICT
);

INSERT INTO ticket_attachments (
  id,
  ticket_id,
  message_id,
  uploaded_by,
  object_key,
  original_name,
  mime_type,
  size_bytes,
  created_at
)
SELECT
  a.id,
  a.ticket_id,
  CASE
    WHEN a.message_id IS NULL THEN NULL
    WHEN EXISTS (
      SELECT 1
      FROM ticket_messages m
      WHERE m.id = a.message_id
        AND m.ticket_id = a.ticket_id
    ) THEN a.message_id
    ELSE NULL
  END,
  a.uploaded_by,
  a.object_key,
  a.original_name,
  a.mime_type,
  a.size_bytes,
  a.created_at
FROM ticket_attachments_old a;

CREATE INDEX idx_ticket_attachments_ticket_id ON ticket_attachments (ticket_id);
CREATE INDEX idx_ticket_attachments_message_id ON ticket_attachments (message_id);
CREATE INDEX idx_ticket_attachments_uploaded_by ON ticket_attachments (uploaded_by);

DROP TABLE ticket_attachments_old;
DROP TABLE ticket_messages_old;

DROP INDEX idx_tickets_customer_id;
DROP INDEX idx_tickets_status;

CREATE INDEX idx_tickets_customer_created
ON tickets (customer_id, created_at DESC);

CREATE INDEX idx_tickets_status_updated
ON tickets (status, updated_at DESC);
