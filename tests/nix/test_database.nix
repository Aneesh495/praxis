# Praxis Pure Nix Test Suite: Database Schema Diffing & Migration DDL

let
  lib = import ../../lib {};
  modules = import ../../modules { inherit lib; };
  runner = import ./test_runner.nix;
  diff = modules.database.diff;
  codegen = modules.database.codegen;

in
runner.runSuite "database" [
  (runner.testCase "schema_diff_detects_new_table" (_:
    let
      v1 = {};
      v2 = {
        "users" = {
          columns = {
            "id" = { type = "uuid"; nullable = false; primaryKey = true; };
            "name" = { type = "text"; nullable = false; };
          };
          indexes = {};
        };
      };
      d = diff.diffSchemas v1 v2;
    in
    d.createdTables == [ "users" ] && d.droppedTables == []
  ))

  (runner.testCase "schema_diff_detects_added_column" (_:
    let
      v1 = {
        "orders" = {
          columns = {
            "id" = { type = "bigint"; nullable = false; primaryKey = true; };
          };
          indexes = {};
        };
      };
      v2 = {
        "orders" = {
          columns = {
            "id" = { type = "bigint"; nullable = false; primaryKey = true; };
            "status" = { type = "varchar"; nullable = false; default = "'PENDING'"; };
          };
          indexes = {};
        };
      };
      d = diff.diffSchemas v1 v2;
    in
    d.createdTables == [] &&
    d.tables."orders".addedCols == [ "status" ]
  ))

  (runner.testCase "generate_postgres_ddl" (_:
    let
      v1 = {};
      v2 = {
        "accounts" = {
          columns = {
            "id" = { type = "uuid"; nullable = false; primaryKey = true; };
            "balance" = { type = "numeric"; nullable = false; default = "0"; };
          };
          indexes = {
            "idx_accounts_balance" = {
              columns = [ "balance" ];
              unique = false;
              method = "btree";
            };
          };
        };
      };
      d = diff.diffSchemas v1 v2;
      sql = codegen.generatePostgresUp d v2;
    in
    builtins.match ".*CREATE TABLE IF NOT EXISTS accounts.*" sql != null &&
    builtins.match ".*id UUID NOT NULL PRIMARY KEY.*" sql != null
  ))
]
