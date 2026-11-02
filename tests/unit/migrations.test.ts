import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { join } from "node:path";
import { tmpdir } from "node:os";

import { afterEach, describe, expect, it } from "vitest";

const migrationsDir =
  "/home/runner/work/core-ticket-system/core-ticket-system/migrations";

const migrationSql = (file: string): string =>
  readFileSync(join(migrationsDir, file), "utf8");

const applySql = (databasePath: string, sql: string): void => {
  execFileSync("sqlite3", [databasePath], {
    input: `PRAGMA foreign_keys = ON;\n${sql}`,
  });
};

const queryRows = (databasePath: string, sql: string): string[] => {
  const output = execFileSync("sqlite3", [databasePath, sql], {
    encoding: "utf8",
  }).trim();

  if (output.length === 0) {
    return [];
  }

  return output.split("\n");
};

describe("database migrations", () => {
  const tempDirectories: string[] = [];

  afterEach(() => {
    for (const directory of tempDirectories.splice(0)) {
      rmSync(directory, { recursive: true, force: true });
    }
  });

  it("normalizes user emails and enforces case-insensitive uniqueness", () => {
    const tempDirectory = mkdtempSync(join(tmpdir(), "cts-migration-email-"));
    tempDirectories.push(tempDirectory);

    const databasePath = join(tempDirectory, "db.sqlite");

    applySql(databasePath, migrationSql("0001_initial.sql"));

    applySql(
      databasePath,
      `
      INSERT INTO users (id, name, email, password_hash, role, is_active, created_at, updated_at)
      VALUES ('user-1', 'Admin User', '  Admin@Example.com  ', 'hash', 'admin', 1, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z');
      `,
    );

    applySql(databasePath, migrationSql("0002_schema_improvements.sql"));

    const emails = queryRows(
      databasePath,
      "SELECT email FROM users WHERE id = 'user-1';",
    );
    expect(emails).toEqual(["admin@example.com"]);

    expect(() => {
      applySql(
        databasePath,
        `
        INSERT INTO users (id, name, email, password_hash, role, is_active, created_at, updated_at)
        VALUES ('user-2', 'Duplicate User', 'ADMIN@EXAMPLE.COM', 'hash', 'customer', 1, '2026-01-02T00:00:00.000Z', '2026-01-02T00:00:00.000Z');
        `,
      );
    }).toThrow(/UNIQUE constraint failed: users\.email/i);
  });

  it("preserves attachment/message ticket consistency after migration", () => {
    const tempDirectory = mkdtempSync(
      join(tmpdir(), "cts-migration-attachment-"),
    );
    tempDirectories.push(tempDirectory);

    const databasePath = join(tempDirectory, "db.sqlite");

    applySql(databasePath, migrationSql("0001_initial.sql"));

    applySql(
      databasePath,
      `
      INSERT INTO users (id, name, email, password_hash, role, is_active, created_at, updated_at)
      VALUES
        ('user-1', 'Customer User', 'customer@example.com', 'hash', 'customer', 1, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
        ('user-2', 'Support User', 'support@example.com', 'hash', 'admin', 1, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z');

      INSERT INTO tickets (id, customer_id, category_id, subject, description, status, priority, metadata, created_at, updated_at)
      VALUES
        ('ticket-1', 'user-1', NULL, 'Issue 1', 'Initial issue', 'open', 'normal', NULL, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
        ('ticket-2', 'user-1', NULL, 'Issue 2', 'Second issue', 'open', 'normal', NULL, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z');

      INSERT INTO ticket_messages (id, ticket_id, author_id, message, created_at)
      VALUES ('message-1', 'ticket-1', 'user-2', 'Reply', '2026-01-01T01:00:00.000Z');

      INSERT INTO ticket_attachments (id, ticket_id, message_id, uploaded_by, object_key, original_name, mime_type, size_bytes, created_at)
      VALUES ('attachment-1', 'ticket-2', 'message-1', 'user-2', 'obj-1', 'proof.txt', 'text/plain', 128, '2026-01-01T01:05:00.000Z');
      `,
    );

    applySql(databasePath, migrationSql("0002_schema_improvements.sql"));

    const migratedMessageReference = queryRows(
      databasePath,
      "SELECT COALESCE(message_id, 'NULL') FROM ticket_attachments WHERE id = 'attachment-1';",
    );
    expect(migratedMessageReference).toEqual(["NULL"]);

    expect(() => {
      applySql(
        databasePath,
        `
        INSERT INTO ticket_attachments (id, ticket_id, message_id, uploaded_by, object_key, original_name, mime_type, size_bytes)
        VALUES ('attachment-2', 'ticket-2', 'message-1', 'user-2', 'obj-2', 'mismatch.txt', 'text/plain', 64);
        `,
      );
    }).toThrow(/FOREIGN KEY constraint failed/i);

    applySql(
      databasePath,
      `
      INSERT INTO ticket_messages (id, ticket_id, author_id, message)
      VALUES ('message-2', 'ticket-2', 'user-2', 'Valid reply');

      INSERT INTO ticket_attachments (id, ticket_id, message_id, uploaded_by, object_key, original_name, mime_type, size_bytes)
      VALUES ('attachment-3', 'ticket-2', 'message-2', 'user-2', 'obj-3', 'valid.txt', 'text/plain', 64);
      `,
    );

    const defaultTimestamps = queryRows(
      databasePath,
      "SELECT created_at FROM ticket_attachments WHERE id = 'attachment-3';",
    );

    expect(defaultTimestamps).toHaveLength(1);
    expect(defaultTimestamps[0]).toMatch(/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/);
  });

  it("adds query-oriented ticket indexes and removes redundant single-column indexes", () => {
    const tempDirectory = mkdtempSync(join(tmpdir(), "cts-migration-indexes-"));
    tempDirectories.push(tempDirectory);

    const databasePath = join(tempDirectory, "db.sqlite");

    applySql(databasePath, migrationSql("0001_initial.sql"));
    applySql(databasePath, migrationSql("0002_schema_improvements.sql"));

    const indexes = queryRows(
      databasePath,
      "SELECT name FROM pragma_index_list('tickets') ORDER BY name;",
    );

    expect(indexes).toContain("idx_tickets_category_id");
    expect(indexes).toContain("idx_tickets_customer_created");
    expect(indexes).toContain("idx_tickets_status_updated");
    expect(indexes).not.toContain("idx_tickets_customer_id");
    expect(indexes).not.toContain("idx_tickets_status");
  });
});
