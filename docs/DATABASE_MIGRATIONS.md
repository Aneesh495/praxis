# Praxis Relational Schema Migrations

Praxis features a declarative database modeling subsystem (`modules/database/`) that represents relational database schemas as pure Nix data structures and automatically synthesizes zero-downtime, safe SQL DDL migration scripts via semantic AST diffing.

```
+========================================================================================+
|                              SCHEMA DIFFING AND MIGRATION                              |
+========================================================================================+
|                                                                                        |
|   +--------------------------+                         +---------------------------+   |
|   | Target Schema (Nix AST)  |                         | Current Schema (Nix AST)  |   |
|   |  - Table: users          |                         |  - Table: users           |   |
|   |    id: uuid PK           |                         |    id: uuid PK            |   |
|   |    email: text UNIQUE    |                         |    email: text UNIQUE     |   |
|   |    created_at: timestamp |                         |  (Missing created_at)     |   |
|   |    mfa_enabled: bool     |                         |  (Missing mfa_enabled)    |   |
|   +------------+-------------+                         +-------------+-------------+   |
|                |                                                     |                 |
|                +--------------------------+  +-----------------------+                 |
|                                           |  |                                         |
|                                           v  v                                         |
|                              +----------------------------+                            |
|                              | Relational AST Diff Engine |                            |
|                              | Computes delta operations  |                            |
|                              +-------------+--------------+                            |
|                                            |                                           |
|                                            v                                           |
|                              +----------------------------+                            |
|                              | Zero-Downtime SQL DDL Gen  |                            |
|                              | Safe locks, concurrent idx |                            |
|                              +-------------+--------------+                            |
|                                            |                                           |
|                                            v                                           |
|                              +----------------------------+                            |
|                              | Up and Down Migration Files|                            |
|                              | Transactional SQL Scripts  |                            |
|                              +----------------------------+                            |
+========================================================================================+
```

---

## 1. Declarative Schema Specification

Relational schemas are expressed as typed Nix records:

```nix
database.schemas.core = {
  tables.users = {
    columns = {
      id = { type = "uuid"; primaryKey = true; default = "gen_random_uuid()"; };
      username = { type = "varchar(64)"; nullable = false; unique = true; };
      email = { type = "varchar(255)"; nullable = false; unique = true; };
      tier = { type = "varchar(32)"; nullable = false; default = "'standard'"; };
      created_at = { type = "timestamptz"; nullable = false; default = "clock_timestamp()"; };
    };

    indexes = {
      idx_users_email = {
        columns = [ "email" ];
        method = "btree";
        unique = true;
      };
      idx_users_created = {
        columns = [ "created_at" ];
        method = "btree";
      };
    };

    constraints = [
      {
        name = "chk_username_len";
        check = "length(username) >= 3";
      }
    ];
  };
};
```

Supported column types include: `uuid`, `varchar(n)`, `text`, `integer`, `bigint`, `boolean`, `timestamptz`, `jsonb`, `numeric(p, s)`, `bytea`.

---

## 2. AST Semantic Diffing Engine

The diffing engine (`modules/database/migration.nix`) compares two schema versions, classifying modifications into distinct structural operations:

```
Delta Hierarchy:
├── Tables
│   ├── CreateTable(table_name, columns, constraints)
│   └── DropTable(table_name)
├── Columns
│   ├── AddColumn(table_name, column_name, spec)
│   ├── DropColumn(table_name, column_name)
│   ├── AlterColumnType(table_name, column_name, old_type, new_type)
│   └── SetNullable(table_name, column_name, is_nullable)
├── Constraints
│   ├── AddConstraint(table_name, constraint)
│   └── DropConstraint(table_name, constraint_name)
└── Indexes
    ├── CreateIndex(table_name, index_name, spec)
    └── DropIndex(table_name, index_name)
```

---

## 3. Zero-Downtime Safe DDL Generation

In production databases, naive `ALTER TABLE` statements acquire `ACCESS EXCLUSIVE` table locks, stalling all concurrent read and write queries. Praxis enforces safety rules that guarantee zero-downtime execution:

### 3.1 Non-Blocking Column Additions
When adding non-nullable columns with defaults, Praxis leverages PostgreSQL modern fast-default optimizations (avoiding table rewrites) or generates multi-phase migration steps:

```sql
-- Phase 1: Add column as nullable with default
ALTER TABLE users ADD COLUMN tier varchar(32) DEFAULT 'standard';

-- Phase 2: Validate existing rows and set NOT NULL
ALTER TABLE users ALTER COLUMN tier SET NOT NULL;
```

### 3.2 Concurrent Index Creation
All indexes are synthesized using concurrent execution directives:

```sql
-- Safe concurrent index creation (does not block writes)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_created
ON users USING btree (created_at);
```

When generating down migrations, indexes are dropped concurrently:

```sql
DROP INDEX CONCURRENTLY IF EXISTS idx_users_created;
```

### 3.3 Transactional Boundaries and Rollbacks
Migration files are wrapped in atomic transaction envelopes (`BEGIN; ... COMMIT;`), ensuring that any execution failure causes an immediate rollback without leaving the database catalog in an inconsistent state.
