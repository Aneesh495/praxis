# Praxis Declarative Infrastructure Hypervisor
# Database Module: Declarative Relational Schema Modeling
#
# Declares tables, columns, primary keys, foreign keys, unique constraints,
# check constraints, and partial indexes directly in pure Nix.

{ lib, ... }:

let
  types = lib.types;
in
{
  options.praxis.database.schema = {
    enable = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to manage relational database schemas and migrations.";
    };

    engine = lib.mkOption {
      type = types.enum [ "postgresql" "sqlite" "clickhouse" ];
      default = "postgresql";
      description = "Relational database SQL dialect engine.";
    };

    tables = lib.mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          columns = lib.mkOption {
            type = types.attrsOf (types.submodule {
              options = {
                type = lib.mkOption {
                  type = types.enum [
                    "uuid" "bigint" "integer" "smallint" "text" "varchar" "boolean"
                    "timestamptz" "timestamp" "date" "jsonb" "bytea" "numeric" "double"
                  ];
                  description = "SQL column data type.";
                };

                nullable = lib.mkOption {
                  type = types.bool;
                  default = false;
                  description = "Whether column allows NULL values.";
                };

                default = lib.mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Default SQL expression value.";
                };

                primaryKey = lib.mkOption {
                  type = types.bool;
                  default = false;
                  description = "Whether this column is part of primary key.";
                };
              };
            });
            description = "Column definitions in table.";
          };

          indexes = lib.mkOption {
            type = types.attrsOf (types.submodule {
              options = {
                columns = lib.mkOption { type = types.listOf types.str; description = "Columns covered by index."; };
                unique = lib.mkOption { type = types.bool; default = false; description = "Whether index enforces uniqueness."; };
                method = lib.mkOption { type = types.enum [ "btree" "hash" "gin" "gist" ]; default = "btree"; description = "Index algorithm."; };
                predicate = lib.mkOption { type = types.nullOr types.str; default = null; description = "WHERE clause for partial index."; };
              };
            });
            default = {};
            description = "Table indexes.";
          };
        };
      });
      default = {};
      description = "Declarative relational schema tables.";
    };
  };
}
