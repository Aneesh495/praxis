# Praxis Pure Nix Standard Library
# Deterministic JSON Serialization and Encoding Engine
#
# Emits byte-for-byte reproducible JSON with alphabetically sorted object keys,
# strict character escaping, and optional configurable indentation. Underpins
# OCI image manifests, SLSA provenance documents, and CloudFormation templates.

rec {
  # Escapes JSON special characters within a string
  escapeJsonString = str:
    builtins.toJSON str; # builtins.toJSON handles string escaping natively

  # Serializes an arbitrary Nix value into deterministic compact JSON
  toCompactJSON = val:
    if val == null then "null"
    else if builtins.isBool val then (if val then "true" else "false")
    else if builtins.isInt val then toString val
    else if builtins.isString val then escapeJsonString val
    else if builtins.isList val then
      let
        items = builtins.map toCompactJSON val;
      in
      "[" + (builtins.concatStringsSep "," items) + "]"
    else if builtins.isAttrs val then
      let
        # Sort keys lexicographically for determinism
        keys = builtins.sort (a: b: a < b) (builtins.attrNames val);
        pairs = builtins.map (k:
          (escapeJsonString k) + ":" + (toCompactJSON val.${k})
        ) keys;
      in
      "{" + (builtins.concatStringsSep "," pairs) + "}"
    else
      throw "Praxis toCompactJSON: unsupported type for value: ${builtins.typeOf val}";

  # Serializes an arbitrary Nix value into indented, human-readable deterministic JSON
  toPrettyJSON = indent: val:
    let
      spaces = builtins.concatStringsSep "" (builtins.genList (_: " ") indent);
      go = currentIndent: v:
        let
          curSpaces = builtins.concatStringsSep "" (builtins.genList (_: " ") currentIndent);
          nextSpaces = builtins.concatStringsSep "" (builtins.genList (_: " ") (currentIndent + indent));
        in
        if v == null then "null"
        else if builtins.isBool v then (if v then "true" else "false")
        else if builtins.isInt v then toString v
        else if builtins.isString v then escapeJsonString v
        else if builtins.isList v then
          if v == [] then "[]"
          else
            let
              items = builtins.map (item: nextSpaces + (go (currentIndent + indent) item)) v;
            in
            "[\n" + (builtins.concatStringsSep ",\n" items) + "\n" + curSpaces + "]"
        else if builtins.isAttrs v then
          if v == {} then "{}"
          else
            let
              keys = builtins.sort (a: b: a < b) (builtins.attrNames v);
              pairs = builtins.map (k:
                nextSpaces + (escapeJsonString k) + ": " + (go (currentIndent + indent) v.${k})
              ) keys;
            in
            "{\n" + (builtins.concatStringsSep ",\n" pairs) + "\n" + curSpaces + "}"
        else
          throw "Praxis toPrettyJSON: unsupported type: ${builtins.typeOf v}";
    in
    go 0 val;

  # Default JSON serialization with 2-space indentation
  toJSON = toPrettyJSON 2;
}
