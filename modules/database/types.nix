# Praxis Declarative Infrastructure Hypervisor
# Database Module: Column Data Types and Constraints
#
# Declares standard ANSI and PostgreSQL relational data types, nullability,
# default expressions, and foreign key referential integrity constraints.

{ lib, ... }:

let
  types = lib.types;
in
{
  options.praxis.database.columnType = lib.mkOption {
    type = types.enum [
      "uuid" "bigint" "integer" "smallint" "text" "varchar" "boolean"
      "timestamptz" "timestamp" "date" "jsonb" "bytea" "numeric" "double"
    ];
    default = "text";
    description = "Relational SQL data type.";
  };
}
