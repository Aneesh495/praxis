# Praxis Declarative Infrastructure Hypervisor
# Database Module: SQL DDL Migration Synthesizer
#
# Compiles schema diffs into production SQL DDL scripts (PostgreSQL, SQLite, ClickHouse)
# with zero-downtime safety patterns (CONCURRENTLY index builds, lock-safe columns).

let
  diff = import ./diff.nix;

  typeToPg = t:
    let
      map = {
        "uuid" = "UUID";
        "bigint" = "BIGINT";
        "integer" = "INTEGER";
        "smallint" = "SMALLINT";
        "text" = "TEXT";
        "varchar" = "VARCHAR(255)";
        "boolean" = "BOOLEAN";
        "timestamptz" = "TIMESTAMPTZ";
        "timestamp" = "TIMESTAMP";
        "date" = "DATE";
        "jsonb" = "JSONB";
        "bytea" = "BYTEA";
        "numeric" = "NUMERIC";
        "double" = "DOUBLE PRECISION";
      };
    in
    if builtins.hasAttr t map then map.${t} else "TEXT";

in
rec {
  # Generates forward migration SQL for PostgreSQL
  generatePostgresUp = diffResult: targetSchema:
    let
      # 1. CREATE TABLE statements
      createTableStatements = builtins.map (table:
        let
          tDef = targetSchema.${table};
          colNames = builtins.sort (a: b: a < b) (builtins.attrNames tDef.columns);
          colDefs = builtins.map (cName:
            let
              c = tDef.columns.${cName};
              typeSql = typeToPg c.type;
              nullSql = if c.nullable then "" else " NOT NULL";
              defaultSql = if c.default != null then " DEFAULT ${c.default}" else "";
              pkSql = if c.primaryKey then " PRIMARY KEY" else "";
            in
            "    ${cName} ${typeSql}${nullSql}${defaultSql}${pkSql}"
          ) colNames;
        in
        "CREATE TABLE IF NOT EXISTS ${table} (\n" +
        (builtins.concatStringsSep ",\n" colDefs) +
        "\n);"
      ) diffResult.createdTables;

      # 2. ALTER TABLE statements for modified tables
      alterTableStatements = builtins.concatMap (table:
        let
          tDiff = diffResult.tables.${table};
          tDef = targetSchema.${table};

          # Added columns
          addColStmts = builtins.map (cName:
            let
              c = tDef.columns.${cName};
              typeSql = typeToPg c.type;
              nullSql = if c.nullable then "" else " NOT NULL";
              defaultSql = if c.default != null then " DEFAULT ${c.default}" else "";
            in
            "ALTER TABLE ${table} ADD COLUMN IF NOT EXISTS ${cName} ${typeSql}${defaultSql}${nullSql};"
          ) tDiff.addedCols;

          # Added indexes
          addIdxStmts = builtins.map (iName:
            let
              idx = tDef.indexes.${iName};
              uniqueSql = if idx.unique then "UNIQUE " else "";
              colsSql = builtins.concatStringsSep ", " idx.columns;
              predSql = if idx.predicate != null then " WHERE ${idx.predicate}" else "";
            in
            "CREATE ${uniqueSql}INDEX CONCURRENTLY IF NOT EXISTS ${iName} ON ${table} USING ${idx.method} (${colsSql})${predSql};"
          ) tDiff.addedIdxs;
        in
        addColStmts ++ addIdxStmts
      ) (builtins.attrNames diffResult.tables);

      allStatements = createTableStatements ++ alterTableStatements;
    in
    builtins.concatStringsSep "\n\n" allStatements + "\n";
}
