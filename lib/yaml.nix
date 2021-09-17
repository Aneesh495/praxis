# Praxis Pure Nix Standard Library
# Deterministic YAML 1.2 Serialization Engine
#
# Emits clean, deterministic, byte-for-byte reproducible YAML 1.2 documents
# with sorted keys, block-style mappings, and proper scalar quoting. Used for
# Kubernetes manifests, Helm values, and Compose topologies.

rec {
  # Characters that require quotes in YAML scalar values
  needsQuotes = str:
    let
      specials = [ ":" "{" "}" "[" "]" "," "&" "*" "#" "?" "|" "-" "<" ">" "=" "!" "%" "@" "`" "\n" "\"" "'" ];
    in
    str == "" ||
    str == "true" || str == "false" || str == "yes" || str == "no" || str == "null" ||
    builtins.any (char: builtins.match (".*" + char + ".*") str != null) specials;

  # Formats a scalar value into valid YAML string
  formatScalar = val:
    if val == null then "null"
    else if builtins.isBool val then (if val then "true" else "false")
    else if builtins.isInt val then toString val
    else if builtins.isString val then
      if needsQuotes val then builtins.toJSON val else val
    else
      throw "Praxis formatScalar: non-scalar value encountered: ${builtins.typeOf val}";

  # Serializes arbitrary Nix data to indented YAML
  toYAML = val:
    let
      go = indent: v:
        let
          spaces = builtins.concatStringsSep "" (builtins.genList (_: " ") indent);
        in
        if builtins.isAttrs v then
          if v == {} then "{}"
          else
            let
              keys = builtins.sort (a: b: a < b) (builtins.attrNames v);
              lines = builtins.concatMap (k:
                let
                  subVal = v.${k};
                in
                if builtins.isAttrs subVal then
                  if subVal == {} then [ "${spaces}${k}: {}" ]
                  else [ "${spaces}${k}:" ] ++ (go (indent + 2) subVal)
                else if builtins.isList subVal then
                  if subVal == [] then [ "${spaces}${k}: []" ]
                  else [ "${spaces}${k}:" ] ++ (go (indent + 2) subVal)
                else
                  [ "${spaces}${k}: ${formatScalar subVal}" ]
              ) keys;
            in
            lines
        else if builtins.isList v then
          if v == [] then "[]"
          else
            let
              lines = builtins.concatMap (item:
                if builtins.isAttrs item then
                  let
                    itemLines = go (indent + 2) item;
                    first = builtins.head itemLines;
                    rest = builtins.tail itemLines;
                    # Strip leading spaces from first line and prefix with '- '
                    strippedFirst = builtins.substring (indent + 2) (builtins.stringLength first - (indent + 2)) first;
                  in
                  [ "${spaces}- ${strippedFirst}" ] ++ rest
                else if builtins.isList item then
                  [ "${spaces}-" ] ++ (go (indent + 2) item)
                else
                  [ "${spaces}- ${formatScalar item}" ]
              ) v;
            in
            lines
        else
          [ "${spaces}${formatScalar v}" ];
    in
    builtins.concatStringsSep "\n" (go 0 val) + "\n";
}
