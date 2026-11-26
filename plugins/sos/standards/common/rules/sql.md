---
paths:
  - "**/*.sql"
  - "**/migrations/**"
  - "**/seeds/**"
---

# SQL Rules

- Use parameterized queries ALWAYS (never string interpolation)
- Explicit column names in SELECT (no `SELECT *` in production)
- All tables must have a primary key
- Foreign keys with ON DELETE/ON UPDATE constraints
- Indexes on columns used in WHERE, JOIN, ORDER BY
- Use transactions for multi-statement operations
- Migration files: sequential versioning (`V001__description.sql`)

## Naming Convention

| Element | Pattern | Example |
|---------|---------|---------|
| Table | lowercase, plural, snake_case | `users`, `order_items` |
| Column | lowercase, snake_case | `created_at`, `user_id` |
| Primary Key | `id` or `{table}_id` | `id`, `user_id` |
| Foreign Key | `fk_{table}_{column}_{ref_table}` | `fk_orders_user_id_users` |
| Index | `ix_{table}_{columns}` | `ix_users_email` |
| Unique Index | `uq_{table}_{columns}` | `uq_users_email` |
| Check Constraint | `ck_{table}_{column}` | `ck_orders_total_positive` |

## Formatting (SQLFluff)

- Keywords: UPPERCASE (`SELECT`, `FROM`, `WHERE`)
- Identifiers: lowercase
- Indent: 4 spaces
- One clause per line
- Trailing commas in column lists

## Security

- GRANT minimum privileges (no GRANT ALL)
- Separate read-only and read-write database users
- No DROP TABLE/DATABASE in application code
- Audit log for sensitive data access
- Encrypt sensitive columns at rest

## Migration Best Practices

- Forward-only migrations (no editing deployed migrations)
- Backward-compatible changes (add column before removing old one)
- Data migration separate from schema migration
- Test rollback procedure for every migration

## Forbidden

- String concatenation for queries (SQL injection risk)
- `SELECT *` in production code
- `DROP TABLE` / `TRUNCATE` without explicit confirmation
- Storing passwords in plain text
- Missing indexes on foreign key columns
