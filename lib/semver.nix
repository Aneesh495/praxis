# Praxis Pure Nix Standard Library
# Semantic Versioning 2.0 Parser, Comparator, and Constraint Solver
#
# Implements full SemVer 2.0 specification in pure Nix.
# Powers package dependency resolution, CVE vulnerability advisory matching,
# and OCI container image tag compatibility checks.

let
  # Helper to parse decimal integer strings
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
            c = builtins.substring idx 1 str;
          in
          if builtins.hasAttr c digits then
            go (idx + 1) (acc * 10 + digits.${c})
          else
            -1;
    in
    if str == "" then -1 else go 0 0;

  splitChar = delim: str:
    let
      len = builtins.stringLength str;
      go = idx: current: acc:
        if idx >= len then acc ++ [ current ]
        else
          let
            c = builtins.substring idx 1 str;
          in
          if c == delim then go (idx + 1) "" (acc ++ [ current ])
          else go (idx + 1) (current + c) acc;
    in
    go 0 "" [];

in
rec {
  # Parses a SemVer 2.0 string into structured attribute set:
  # {
  #   major = int;
  #   minor = int;
  #   patch = int;
  #   prerelease = [ str ... ];
  #   build = [ str ... ];
  #   valid = bool;
  # }
  parse = versionStr:
    let
      # Strip build metadata if present (after '+')
      buildParts = splitChar "+" versionStr;
      hasBuild = (builtins.length buildParts) > 1;
      withoutBuild = builtins.elemAt buildParts 0;
      buildMeta = if hasBuild then splitChar "." (builtins.elemAt buildParts 1) else [];

      # Strip prerelease if present (after '-')
      preParts = splitChar "-" withoutBuild;
      hasPre = (builtins.length preParts) > 1;
      coreStr = builtins.elemAt preParts 0;
      prerelease = if hasPre then splitChar "." (builtins.concatStringsSep "-" (builtins.tail preParts)) else [];

      # Split core into MAJOR.MINOR.PATCH
      coreTokens = splitChar "." coreStr;
    in
    if builtins.length coreTokens != 3 then
      { major = 0; minor = 0; patch = 0; prerelease = []; build = []; valid = false; }
    else
      let
        maj = parseDec (builtins.elemAt coreTokens 0);
        min = parseDec (builtins.elemAt coreTokens 1);
        pat = parseDec (builtins.elemAt coreTokens 2);
      in
      if maj < 0 || min < 0 || pat < 0 then
        { major = 0; minor = 0; patch = 0; prerelease = []; build = []; valid = false; }
      else
        {
          major = maj;
          minor = min;
          patch = pat;
          inherit prerelease;
          build = buildMeta;
          valid = true;
        };

  # Compares two parsed SemVer versions.
  # Returns: -1 if v1 < v2, 0 if v1 == v2, 1 if v1 > v2.
  compare = v1: v2:
    if v1.major < v2.major then -1
    else if v1.major > v2.major then 1
    else if v1.minor < v2.minor then -1
    else if v1.minor > v2.minor then 1
    else if v1.patch < v2.patch then -1
    else if v1.patch > v2.patch then 1
    else
      # Prerelease precedence: normal version has higher precedence than prerelease
      let
        v1IsPre = v1.prerelease != [];
        v2IsPre = v2.prerelease != [];
      in
      if !v1IsPre && v2IsPre then 1
      else if v1IsPre && !v2IsPre then -1
      else if !v1IsPre && !v2IsPre then 0
      else
        # Compare prerelease identifiers lexicographically or numerically
        let
          len1 = builtins.length v1.prerelease;
          len2 = builtins.length v2.prerelease;
          minLen = if len1 < len2 then len1 else len2;

          go = idx:
            if idx >= minLen then
              if len1 < len2 then -1 else if len1 > len2 then 1 else 0
            else
              let
                id1 = builtins.elemAt v1.prerelease idx;
                id2 = builtins.elemAt v2.prerelease idx;
                num1 = parseDec id1;
                num2 = parseDec id2;
              in
              if num1 >= 0 && num2 >= 0 then
                if num1 < num2 then -1 else if num1 > num2 then 1 else go (idx + 1)
              else if num1 >= 0 && num2 < 0 then
                -1 # Numeric identifier has lower precedence than string
              else if num1 < 0 && num2 >= 0 then
                1
              else
                if id1 < id2 then -1 else if id1 > id2 then 1 else go (idx + 1);
        in
        go 0;

  # Compare string versions directly: compareStr "1.2.3" "1.2.4"
  compareStr = s1: s2: compare (parse s1) (parse s2);

  # Equality check
  eq = s1: s2: compareStr s1 s2 == 0;

  # Less than
  lt = s1: s2: compareStr s1 s2 == -1;

  # Greater than
  gt = s1: s2: compareStr s1 s2 == 1;

  # Less than or equal
  lte = s1: s2: compareStr s1 s2 <= 0;

  # Greater than or equal
  gte = s1: s2: compareStr s1 s2 >= 0;

  # Checks if a version satisfies a SemVer constraint string.
  # Supported forms:
  # - "= 1.2.3" or "1.2.3"
  # - ">= 1.2.0"
  # - "<= 2.0.0"
  # - "> 1.0.0"
  # - "< 2.0.0"
  # - "^1.2.3": Compatible with version (same major, >= minor/patch)
  # - "~1.2.3": Approximately equivalent (same major and minor, >= patch)
  satisfies = versionStr: constraintStr:
    let
      v = parse versionStr;
      c = constraintStr;
    in
    if !v.valid then false
    else if builtins.substring 0 2 c == ">=" then
      let target = parse (builtins.substring 2 (builtins.stringLength c - 2) c);
      in compare v target >= 0
    else if builtins.substring 0 2 c == "<=" then
      let target = parse (builtins.substring 2 (builtins.stringLength c - 2) c);
      in compare v target <= 0
    else if builtins.substring 0 1 c == ">" then
      let target = parse (builtins.substring 1 (builtins.stringLength c - 1) c);
      in compare v target > 0
    else if builtins.substring 0 1 c == "<" then
      let target = parse (builtins.substring 1 (builtins.stringLength c - 1) c);
      in compare v target < 0
    else if builtins.substring 0 1 c == "^" then
      let
        target = parse (builtins.substring 1 (builtins.stringLength c - 1) c);
      in
      if !target.valid then false
      else if target.major > 0 then
        v.major == target.major && compare v target >= 0
      else if target.minor > 0 then
        v.major == 0 && v.minor == target.minor && v.patch >= target.patch
      else
        v.major == 0 && v.minor == 0 && v.patch == target.patch
    else if builtins.substring 0 1 c == "~" then
      let
        target = parse (builtins.substring 1 (builtins.stringLength c - 1) c);
      in
      if !target.valid then false
      else v.major == target.major && v.minor == target.minor && v.patch >= target.patch
    else
      let
        cleanTarget = if builtins.substring 0 1 c == "=" then builtins.substring 1 (builtins.stringLength c - 1) c else c;
        target = parse cleanTarget;
      in
      compare v target == 0;
}
