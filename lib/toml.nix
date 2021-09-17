# Praxis Pure Nix Standard Library
# Deterministic TOML v1.0 Serialization Engine
#
# Emits valid, reproducible TOML v1.0 documents with nested tables, array-of-tables,
# and typed scalars. Used for Cloud-Hypervisor configs, Firecracker drive maps,
# and Vector observability pipelines.

rec {
  # Format a basic TOML scalar
  formatScalar = val:
    if val == null then "\"\""
    else if builtins.isBool val then (if val then "true" else "false")
    else if builtins.isInt val then toString val
    else if builtins.isString val then builtins.toJSON val
    else if builtins.isList val then
      let
        items = builtins.map formatScalar val;
      in
      "[ " + (builtins.concatStringsSep ", " items) + " ]"
    else
      throw "Praxis toml.formatScalar: cannot format complex value as scalar: ${builtins.typeOf val}";

  # Serializes an attribute set into TOML formatted string
  toTOML = attrs:
    let
      # Separate scalars from nested tables
      allKeys = builtins.sort (a: b: a < b) (builtins.attrNames attrs);

      scalars = builtins.filter (k:
        let v = attrs.${k}; in !builtins.isAttrs v && !(builtins.isList v && v != [] && builtins.isAttrs (builtins.head v))
      ) allKeys;

      tables = builtins.filter (k:
        builtins.isAttrs attrs.${k}
      ) allKeys;

      arrayTables = builtins.filter (k:
        let v = attrs.${k}; in builtins.isList v && v != [] && builtins.isAttrs (builtins.head v)
      ) allKeys;

      # Format top-level scalars
      scalarLines = builtins.map (k:
        "${k} = ${formatScalar attrs.${k}}"
      ) scalars;

      # Format nested tables [section]
      tableSections = builtins.concatMap (tableKey:
        let
          subTable = attrs.${tableKey};
          subKeys = builtins.sort (a: b: a < b) (builtins.attrNames subTable);
          header = "[${tableKey}]";
          body = builtins.map (sk:
            "${sk} = ${formatScalar subTable.${sk}}"
          ) subKeys;
        in
        [ header ] ++ body ++ [ "" ]
      ) tables;

      # Format array of tables [[array_section]]
      arrayTableSections = builtins.concatMap (arrKey:
        let
          list = attrs.${arrKey};
        in
        builtins.concatMap (item:
          let
            itemKeys = builtins.sort (a: b: a < b) (builtins.attrNames item);
            header = "[[${arrKey}]]";
            body = builtins.map (ik:
              "${ik} = ${formatScalar item.${ik}}"
            ) itemKeys;
          in
          [ header ] ++ body ++ [ "" ]
        ) list
      ) arrayTables;

      allLines = scalarLines ++ (if scalarLines != [] && (tableSections != [] || arrayTableSections != []) then [ "" ] else []) ++ tableSections ++ arrayTableSections;
    in
    builtins.concatStringsSep "\n" allLines + "\n";
}
