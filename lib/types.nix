# Praxis Pure Nix Standard Library
# Structural Type System, Contracts, and Refinements
#
# Implements an expressive, sound, and composable type system in pure Nix.
# Supports refined types, dependent contracts, structural submodules, and
# custom monoidal merge semantics.

{ lib ? null }:

let
  # Helper to parse decimal integer strings into integers
  parseDec = str:
    let
      digits = {
        "0" = 0; "1" = 1; "2" = 2; "3" = 3; "4" = 4;
        "5" = 5; "6" = 6; "7" = 7; "8" = 8; "9" = 9;
      };
      len = builtins.stringLength str;
      go = idx: acc:
        if idx >= len then acc
        else
          let
            char = builtins.substring idx 1 str;
          in
          if builtins.hasAttr char digits then
            go (idx + 1) (acc * 10 + digits.${char})
          else
            -1;
    in
    if str == "" then -1 else go 0 0;

  # Split string by single character delimiter
  splitChar = delim: str:
    let
      len = builtins.stringLength str;
      go = idx: current: acc:
        if idx >= len then
          acc ++ [ current ]
        else
          let
            char = builtins.substring idx 1 str;
          in
          if char == delim then
            go (idx + 1) "" (acc ++ [ current ])
          else
            go (idx + 1) (current + char) acc;
    in
    go 0 "" [];

  # Basic regex/pattern checker simulation for hex characters
  isHexChar = c:
    builtins.elem c [
      "0" "1" "2" "3" "4" "5" "6" "7" "8" "9"
      "a" "b" "c" "d" "e" "f"
      "A" "B" "C" "D" "E" "F"
    ];

  # Check if string contains only hex characters
  isHexString = str:
    let
      len = builtins.stringLength str;
      go = idx:
        if idx >= len then true
        else if isHexChar (builtins.substring idx 1 str) then go (idx + 1)
        else false;
    in
    if str == "" then false else go 0;

in
rec {
  # Base constructor for a Praxis option type.
  # name: human readable type description
  # check: unary predicate (value -> bool)
  # merge: binary or n-ary merge function (loc -> defs -> value)
  # description: documentation string
  mkOptionType = {
    name,
    check ? (_: true),
    merge ? (loc: defs: (builtins.head defs).value),
    description ? name,
    nestedTypes ? {},
  }: {
    inherit name check merge description nestedTypes;
    _type = "option-type";
  };

  # Boolean type: true or false.
  bool = mkOptionType {
    name = "bool";
    description = "boolean (true or false)";
    check = builtins.isBool;
    merge = loc: defs:
      let
        last = builtins.elemAt defs (builtins.length defs - 1);
      in
      last.value;
  };

  # Integer type: 64-bit signed integer.
  int = mkOptionType {
    name = "int";
    description = "signed integer";
    check = builtins.isInt;
    merge = loc: defs:
      let
        last = builtins.elemAt defs (builtins.length defs - 1);
      in
      last.value;
  };

  # Bounded integer type: intBetween minVal maxVal.
  intBetween = minVal: maxVal: mkOptionType {
    name = "intBetween ${toString minVal} ${toString maxVal}";
    description = "integer between ${toString minVal} and ${toString maxVal} inclusive";
    check = v: builtins.isInt v && v >= minVal && v <= maxVal;
    merge = loc: defs: (builtins.elemAt defs (builtins.length defs - 1)).value;
  };

  # Positive integer type (> 0).
  positiveInt = mkOptionType {
    name = "positiveInt";
    description = "strictly positive integer (> 0)";
    check = v: builtins.isInt v && v > 0;
    merge = loc: defs: (builtins.elemAt defs (builtins.length defs - 1)).value;
  };

  # Non-negative integer type (>= 0).
  nonNegativeInt = mkOptionType {
    name = "nonNegativeInt";
    description = "non-negative integer (>= 0)";
    check = v: builtins.isInt v && v >= 0;
    merge = loc: defs: (builtins.elemAt defs (builtins.length defs - 1)).value;
  };

  # String type.
  str = mkOptionType {
    name = "str";
    description = "string";
    check = builtins.isString;
    merge = loc: defs:
      let
        last = builtins.elemAt defs (builtins.length defs - 1);
      in
      last.value;
  };

  # Non-empty string type.
  nonEmptyStr = mkOptionType {
    name = "nonEmptyStr";
    description = "non-empty string";
    check = v: builtins.isString v && builtins.stringLength v > 0;
    merge = loc: defs: (builtins.elemAt defs (builtins.length defs - 1)).value;
  };

  # Filesystem path type.
  path = mkOptionType {
    name = "path";
    description = "filesystem path";
    check = builtins.isPath;
    merge = loc: defs: (builtins.elemAt defs (builtins.length defs - 1)).value;
  };

  # Network Port type: 1 to 65535.
  port = mkOptionType {
    name = "port";
    description = "TCP/UDP port number (1-65535)";
    check = v: builtins.isInt v && v >= 1 && v <= 65535;
    merge = loc: defs: (builtins.elemAt defs (builtins.length defs - 1)).value;
  };

  # IPv4 Address type: dotted decimal notation (e.g. "192.168.1.1").
  ipv4 = mkOptionType {
    name = "ipv4";
    description = "IPv4 dotted-quad address";
    check = v:
      if !builtins.isString v then false
      else
        let
          parts = splitChar "." v;
        in
        if builtins.length parts != 4 then false
        else
          builtins.all (part:
            let
              n = parseDec part;
            in
            n >= 0 && n <= 255
          ) parts;
    merge = loc: defs: (builtins.elemAt defs (builtins.length defs - 1)).value;
  };

  # CIDR Block type: IPv4 address with prefix length (e.g. "10.0.0.0/16").
  cidr = mkOptionType {
    name = "cidr";
    description = "IPv4 CIDR block notation (e.g. 10.0.0.0/16)";
    check = v:
      if !builtins.isString v then false
      else
        let
          parts = splitChar "/" v;
        in
        if builtins.length parts != 2 then false
        else
          let
            ipPart = builtins.elemAt parts 0;
            prefixPart = builtins.elemAt parts 1;
            prefix = parseDec prefixPart;
          in
          ipv4.check ipPart && prefix >= 0 && prefix <= 32;
    merge = loc: defs: (builtins.elemAt defs (builtins.length defs - 1)).value;
  };

  # SHA-256 Hash type: 64 hexadecimal characters.
  sha256 = mkOptionType {
    name = "sha256";
    description = "64-character lowercase SHA-256 hexadecimal hash string";
    check = v:
      builtins.isString v &&
      builtins.stringLength v == 64 &&
      isHexString v;
    merge = loc: defs: (builtins.elemAt defs (builtins.length defs - 1)).value;
  };

  # Duration string type: e.g. "30s", "5m", "1h", "2d".
  duration = mkOptionType {
    name = "duration";
    description = "duration string with time unit (e.g. 30s, 5m, 1h, 2d)";
    check = v:
      if !builtins.isString v || builtins.stringLength v < 2 then false
      else
        let
          len = builtins.stringLength v;
          unit = builtins.substring (len - 1) 1 v;
          numStr = builtins.substring 0 (len - 1) v;
          val = parseDec numStr;
        in
        val >= 0 && builtins.elem unit [ "s" "m" "h" "d" ];
    merge = loc: defs: (builtins.elemAt defs (builtins.length defs - 1)).value;
  };

  # Byte size string type: e.g. "1024", "64KB", "128MB", "4GB", "1TB".
  byteSize = mkOptionType {
    name = "byteSize";
    description = "storage size string with units (e.g. 512B, 64KB, 2GB, 1TB) or raw integer bytes";
    check = v:
      if builtins.isInt v then v >= 0
      else if !builtins.isString v then false
      else
        let
          len = builtins.stringLength v;
        in
        if len == 0 then false
        else
          let
            last2 = if len >= 2 then builtins.substring (len - 2) 2 v else "";
            last1 = builtins.substring (len - 1) 1 v;
          in
          if builtins.elem last2 [ "KB" "MB" "GB" "TB" "PB" ] then
            parseDec (builtins.substring 0 (len - 2) v) >= 0
          else if last1 == "B" then
            parseDec (builtins.substring 0 (len - 1) v) >= 0
          else
            parseDec v >= 0;
    merge = loc: defs: (builtins.elemAt defs (builtins.length defs - 1)).value;
  };

  # Enumeration type: value must be one of allowed values in the list.
  enum = values: mkOptionType {
    name = "enum [ ${builtins.concatStringsSep ", " (builtins.map (v: toString v) values)} ]";
    description = "one of the enumeration values";
    check = v: builtins.elem v values;
    merge = loc: defs: (builtins.elemAt defs (builtins.length defs - 1)).value;
  };

  # Nullable type: value can be null or match the inner type.
  nullOr = elemType: mkOptionType {
    name = "nullOr (${elemType.name})";
    description = "null or ${elemType.description}";
    check = v: v == null || elemType.check v;
    merge = loc: defs:
      let
        nonNull = builtins.filter (d: d.value != null) defs;
      in
      if nonNull == [] then null
      else elemType.merge loc nonNull;
    nestedTypes = { inherit elemType; };
  };

  # Homogeneous list type: listOf elemType.
  # Merging concatenates all definition lists in order.
  listOf = elemType: mkOptionType {
    name = "listOf (${elemType.name})";
    description = "list of ${elemType.description}";
    check = v: builtins.isList v && builtins.all elemType.check v;
    merge = loc: defs:
      builtins.concatLists (builtins.map (d: d.value) defs);
    nestedTypes = { inherit elemType; };
  };

  # Homogeneous attribute set type: attrsOf elemType.
  # Merging deeply merges attributes, applying elemType merge on collisions.
  attrsOf = elemType: mkOptionType {
    name = "attrsOf (${elemType.name})";
    description = "attribute set of ${elemType.description}";
    check = v: builtins.isAttrs v && builtins.all elemType.check (builtins.attrValues v);
    merge = loc: defs:
      let
        allKeys = builtins.foldl' (acc: def:
          acc ++ (builtins.filter (k: !builtins.elem k acc) (builtins.attrNames def.value))
        ) [] defs;
      in
      builtins.listToAttrs (builtins.map (key: {
        name = key;
        value =
          let
            keyDefs = builtins.concatMap (def:
              if builtins.hasAttr key def.value then
                [ { file = def.file; value = def.value.${key}; } ]
              else
                []
            ) defs;
          in
          elemType.merge (loc ++ [ key ]) keyDefs;
      }) allKeys);
    nestedTypes = { inherit elemType; };
  };

  # Union of two types: either typeA typeB.
  either = typeA: typeB: mkOptionType {
    name = "either (${typeA.name}) (${typeB.name})";
    description = "${typeA.description} or ${typeB.description}";
    check = v: typeA.check v || typeB.check v;
    merge = loc: defs:
      let
        last = builtins.elemAt defs (builtins.length defs - 1);
      in
      if typeA.check last.value then
        typeA.merge loc defs
      else
        typeB.merge loc defs;
    nestedTypes = { inherit typeA typeB; };
  };

  # Submodule type: instantiates a nested module configuration schema.
  submodule = moduleDef: mkOptionType {
    name = "submodule";
    description = "submodule declaration";
    check = builtins.isAttrs;
    merge = loc: defs:
      # In Praxis, submodules are evaluated via evalModules in modules.nix
      builtins.foldl' (acc: def: acc // def.value) {} defs;
    nestedTypes = { inherit moduleDef; };
  };
}
