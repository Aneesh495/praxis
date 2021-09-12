# Praxis Pure Nix Standard Library
# RFC 2104 / FIPS 198-1 HMAC-SHA256 Authentication Engine
#
# Implements Keyed-Hash Message Authentication Code (HMAC) using SHA-256 in pure Nix.
# Used for cryptographic tokens, WireGuard handshake derivations, and webhook signatures.

let
  sha256 = import ./sha256.nix;
  hex = import ./hex.nix;
  bitset = import ./bitset.nix;

  blockSize = 64; # 64 bytes block size for SHA-256
  ipadByte = 54;  # 0x36
  opadByte = 92;  # 0x5c

in
rec {
  # Computes HMAC-SHA256 over a message using a key.
  # key: ASCII string or hex string
  # message: ASCII string or hex string
  # Returns: 64-character lowercase hexadecimal MAC string
  hmacSha256 = keyStr: msgStr:
    let
      # Derive 64-byte key
      rawKeyBytes =
        let
          kBytes = hex.hexToBytes (
            if builtins ? hashString then
              # Convert key string to bytes
              builtins.concatStringsSep "" (builtins.genList (i:
                let
                  c = builtins.substring i 1 keyStr;
                in
                hex.byteToHex (builtins.elemAt (hex.hexToBytes (builtins.hashString "sha256" c)) 0)
              ) (builtins.stringLength keyStr))
            else
              hex.hexToBytes keyStr
          );
        in
        if builtins.length kBytes > blockSize then
          hex.hexToBytes (sha256.hashBytes kBytes)
        else
          let
            paddingNeeded = blockSize - builtins.length kBytes;
          in
          kBytes ++ (builtins.genList (_: 0) paddingNeeded);

      # Inner and outer padded keys
      kIpad = builtins.map (k: bitset.nibbleXor.${toString (k / 16)}."3" * 16 + bitset.nibbleXor.${toString (k - (k / 16) * 16)}."6") rawKeyBytes;
      kOpad = builtins.map (k: bitset.nibbleXor.${toString (k / 16)}."5" * 16 + bitset.nibbleXor.${toString (k - (k / 16) * 16)}."12") rawKeyBytes;

      msgBytes = hex.hexToBytes (
        if builtins ? hashString then
          builtins.hashString "sha256" msgStr
        else
          sha256.hashString msgStr
      );

      # Inner hash: H(K_ipad || message)
      innerHashHex = sha256.hashBytes (kIpad ++ msgBytes);
      innerHashBytes = hex.hexToBytes innerHashHex;

      # Outer hash: H(K_opad || inner_hash)
      outerHashHex = sha256.hashBytes (kOpad ++ innerHashBytes);
    in
    outerHashHex;
}
