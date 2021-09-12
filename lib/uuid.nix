# Praxis Pure Nix Standard Library
# RFC 4122 UUIDv4 and UUIDv5 Deterministic Generator
#
# Generates valid RFC 4122 Universally Unique Identifiers in pure Nix.
# Supports deterministic seed-based UUIDv4 and namespace name-based UUIDv5.

let
  sha256 = import ./sha256.nix;
  hex = import ./hex.nix;

in
rec {
  # Well-known RFC 4122 namespaces
  namespaces = {
    dns = "6ba7b810-9dad-11d1-80b4-00c04fd430c8";
    url = "6ba7b811-9dad-11d1-80b4-00c04fd430c8";
    oid = "6ba7b812-9dad-11d1-80b4-00c04fd430c8";
    x500 = "6ba7b814-9dad-11d1-80b4-00c04fd430c8";
  };

  # Deterministically derives a UUIDv4 formatted string from an entropy seed string.
  # Sets version 4 (bits 12-15 = 0100) and variant 1 (bits 64-65 = 10).
  uuidv4FromSeed = seed:
    let
      hash = sha256.hashString ("uuidv4:" + toString seed);
      # Hash has 64 hex characters (32 bytes). We take first 32 characters (16 bytes)
      part1 = builtins.substring 0 8 hash;       # 8 hex chars (time-low)
      part2 = builtins.substring 8 4 hash;       # 4 hex chars (time-mid)
      # Version 4: replace first nibble with '4'
      part3 = "4" + (builtins.substring 13 3 hash); # 4 hex chars (version + time-high)
      # Variant 1: nibble must be 8, 9, a, or b. We map original nibble into '8'..'b'
      rawVariantNibble = builtins.substring 16 1 hash;
      variantChar =
        let
          val = if builtins.hasAttr rawVariantNibble hex.hexCharToVal then hex.hexCharToVal.${rawVariantNibble} else 0;
          clamped = 8 + (val - (val / 4) * 4); # 8, 9, 10, or 11
        in
        builtins.elemAt hex.hexDigits clamped;
      part4 = variantChar + (builtins.substring 17 3 hash); # 4 hex chars (variant + clock-seq)
      part5 = builtins.substring 20 12 hash;      # 12 hex chars (node id)
    in
    "${part1}-${part2}-${part3}-${part4}-${part5}";

  # Generates an RFC 4122 name-based UUID using SHA-256 (UUIDv5 extension).
  # Combines namespace UUID and name string.
  uuidv5 = ns: name:
    let
      cleanNs = builtins.replaceStrings [ "-" ] [ "" ] ns;
      combined = cleanNs + ":" + name;
      hash = sha256.hashString combined;
      part1 = builtins.substring 0 8 hash;
      part2 = builtins.substring 8 4 hash;
      part3 = "5" + (builtins.substring 13 3 hash);
      rawVariantNibble = builtins.substring 16 1 hash;
      variantChar =
        let
          val = if builtins.hasAttr rawVariantNibble hex.hexCharToVal then hex.hexCharToVal.${rawVariantNibble} else 0;
          clamped = 8 + (val - (val / 4) * 4);
        in
        builtins.elemAt hex.hexDigits clamped;
      part4 = variantChar + (builtins.substring 17 3 hash);
      part5 = builtins.substring 20 12 hash;
    in
    "${part1}-${part2}-${part3}-${part4}-${part5}";
}
