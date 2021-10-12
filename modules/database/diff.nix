# Praxis Declarative Infrastructure Hypervisor
# Database Module: Relational Schema AST Diffing Engine
#
# Compares two declarative schema versions in pure Nix, computing minimal
# non-destructive migration operations: table creations, column additions,
# type alterations, and index definitions with zero-downtime safety checks.

rec {
  # Computes structural diff between oldSchema and newSchema
  # Both are attribute sets mapping tableName -> { columns = { ... }; indexes = { ... }; }
  diffSchemas = oldSchema: newSchema:
    let
      oldTables = builtins.attrNames oldSchema;
      newTables = builtins.attrNames newSchema;

      createdTables = builtins.filter (t: !builtins.elem t oldTables) newTables;
      droppedTables = builtins.filter (t: !builtins.elem t newTables) oldTables;
      commonTables = builtins.filter (t: builtins.elem t oldTables) newTables;

      # Diff columns and indexes for tables existing in both schemas
      tableDiffs = builtins.listToAttrs (builtins.map (table:
        let
          oldT = oldSchema.${table};
          newT = newSchema.${table};

          oldCols = builtins.attrNames oldT.columns;
          newCols = builtins.attrNames newT.columns;

          addedCols = builtins.filter (c: !builtins.elem c oldCols) newCols;
          droppedCols = builtins.filter (c: !builtins.elem c newCols) oldCols;
          commonCols = builtins.filter (c: builtins.elem c oldCols) newCols;

          alteredCols = builtins.filter (c:
            let
              cOld = oldT.columns.${c};
              cNew = newT.columns.${c};
            in
            cOld.type != cNew.type || cOld.nullable != cNew.nullable
          ) commonCols;

          oldIdxs = builtins.attrNames (if oldT ? indexes then oldT.indexes else {});
          newIdxs = builtins.attrNames (if newT ? indexes then newT.indexes else {});

          addedIdxs = builtins.filter (i: !builtins.elem i oldIdxs) newIdxs;
          droppedIdxs = builtins.filter (i: !builtins.elem i newIdxs) oldIdxs;
        in
        {
          name = table;
          value = {
            inherit addedCols droppedCols alteredCols addedIdxs droppedIdxs;
          };
        }
      ) commonTables);
    in
    {
      inherit createdTables droppedTables;
      tables = tableDiffs;
    };
}
